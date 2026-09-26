"""R2-05 regression: recognized-revenue analytics integrity.

Hermetic Flask test-client tests with a fake Firestore (no network/mutation).
Single revenue predicate under test:
  revenue = {confirmed, shipped, out_for_delivery, delivered, paid}
  pipeline-only (never revenue) = {pending, cancelled, unknown}
"""
import os
import sys
from datetime import datetime, timezone, timedelta
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from app import create_app  # noqa: E402


# --- Fake Firestore ----------------------------------------------------------

class _FakeDoc:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = dict(data)

    def to_dict(self):
        return dict(self._data)


class _FakeQuery:
    def __init__(self, docs):
        self._docs = list(docs)

    def stream(self):
        return [_FakeDoc(d.get('id', f'doc_{i}'), d) for i, d in enumerate(self._docs)]


class _FakeCollection:
    def __init__(self, docs):
        self._docs = list(docs)

    def where(self, *args, **kwargs):
        # analytics filters artisan_id == X; emulate equality on field/value.
        if len(args) >= 3 and args[1] == '==':
            field, value = args[0], args[2]
            return _FakeQuery([d for d in self._docs if d.get(field) == value])
        return _FakeQuery(self._docs)

    def stream(self):
        return _FakeQuery(self._docs).stream()


class _FakeDB:
    def __init__(self, orders):
        self._orders = list(orders)

    def collection(self, name):
        if name == 'orders':
            return _FakeCollection(self._orders)
        return _FakeCollection([])


def _client_with_orders(orders):
    from routes import analytics as analytics_route
    fake_db = _FakeDB(orders)
    app = create_app()
    app.config.update(TESTING=True)
    patcher = patch.object(analytics_route, 'get_firestore_client', return_value=fake_db)
    patcher.start()
    return app.test_client(), patcher


def _order(status, price=1000.0, qty=1, pid='p1', title='Item', created=None, artisan='a1'):
    return {
        'id': f'{pid}_{status}_{price}',
        'artisan_id': artisan,
        'status': status,
        'total_price': price,
        'quantity': qty,
        'product_id': pid,
        'product_title': title,
        'created_at': created or datetime.now(timezone.utc).isoformat(),
    }


def _summary(client, artisan='a1'):
    resp = client.get('/api/analytics/summary', query_string={'artisan_id': artisan})
    assert resp.status_code == 200, resp.get_data(as_text=True)
    body = resp.get_json()
    assert body['success'] is True
    return body['data']


def test_zero_orders():
    client, p = _client_with_orders([])
    try:
        data = _summary(client)
        assert data['total_orders'] == 0
        assert data['total_revenue'] == 0
        assert data['average_order_value'] == 0
        assert data['best_selling_product']['title'] == 'No sales yet'
        assert data['best_selling_product']['units_sold'] == 0
    finally:
        p.stop()


def test_pending_excluded_from_revenue():
    o = _order('pending', price=1000, qty=2, pid='pp', title='Pending Pot')
    client, p = _client_with_orders([o])
    try:
        data = _summary(client)
        assert data['total_orders'] == 1
        assert data['order_status_counts']['pending'] == 1
        assert data['total_revenue'] == 0
        assert data['average_order_value'] == 0
        assert data['best_selling_product']['title'] == 'No sales yet'
        assert all(b['revenue'] == 0 and b['orders'] == 0 for b in data['monthly_trend'])
    finally:
        p.stop()


def test_cancelled_excluded_from_revenue():
    o = _order('cancelled', price=2000, qty=1, pid='cc', title='Cancelled Cloth')
    client, p = _client_with_orders([o])
    try:
        data = _summary(client)
        assert data['total_orders'] == 1
        assert data['total_revenue'] == 0
        assert data['best_selling_product']['title'] == 'No sales yet'
    finally:
        p.stop()


def test_each_revenue_status_recognized():
    for status in ['confirmed', 'shipped', 'out_for_delivery', 'delivered', 'paid']:
        o = _order(status, price=500, qty=1, pid=f'p_{status}', title=f'T_{status}')
        client, p = _client_with_orders([o])
        try:
            data = _summary(client)
            assert data['total_revenue'] == 500, status
            assert data['best_selling_product']['id'] == f'p_{status}', status
        finally:
            p.stop()


def test_paid_counts_as_completed():
    orders = [_order('delivered', price=100, pid='d'), _order('paid', price=200, pid='p')]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['completed_orders'] == 2
        assert data['order_status_counts']['delivered'] == 1
        assert data['order_status_counts']['paid'] == 1
    finally:
        p.stop()


def test_aov_uses_recognized_count():
    orders = [
        _order('pending', price=1000, pid='x1', title='X1'),
        _order('cancelled', price=1000, pid='x2', title='X2'),
        _order('confirmed', price=3000, qty=1, pid='c1', title='C1'),
        _order('shipped', price=5000, qty=1, pid='s1', title='S1'),
    ]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['total_orders'] == 4
        assert data['total_revenue'] == 8000
        assert data['average_order_value'] == 4000
    finally:
        p.stop()


def test_best_seller_uses_recognized_only():
    orders = [
        _order('pending', price=99999, qty=99, pid='fake', title='Fake Pending'),
        _order('cancelled', price=50000, qty=50, pid='fake2', title='Fake Cancelled'),
        _order('confirmed', price=3000, qty=2, pid='real', title='Real Pot'),
    ]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['best_selling_product']['id'] == 'real'
        assert data['best_selling_product']['units_sold'] == 2
    finally:
        p.stop()


def test_no_sales_state_when_only_pipeline():
    orders = [_order('pending', price=100, pid='a'), _order('cancelled', price=200, pid='b')]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['total_orders'] == 2
        assert data['total_revenue'] == 0
        assert data['best_selling_product']['title'] == 'No sales yet'
    finally:
        p.stop()


def test_monthly_excludes_pipeline_and_year_boundary():
    now = datetime.now(timezone.utc)
    cur_iso = now.isoformat()
    prev_month = 12 if now.month == 1 else now.month - 1
    prev_year = now.year - 1 if now.month == 1 else now.year
    prev_iso = now.replace(year=prev_year, month=prev_month, day=1).isoformat()
    # Same month abbreviation but one year earlier (outside 6-month window).
    old_year = now.year - 1
    old_iso = now.replace(year=old_year, day=1).isoformat()
    orders = [
        _order('confirmed', price=1000, pid='cur', created=cur_iso),
        _order('pending', price=9999, pid='pend', created=cur_iso),
        _order('cancelled', price=8888, pid='canc', created=prev_iso),
        _order('delivered', price=500, pid='prev', created=prev_iso),
        _order('delivered', price=7777, pid='old', created=old_iso),
    ]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['revenue_this_month'] == 1000
        assert data['revenue_last_month'] == 500
        # Current-month bucket has exactly the 1 recognized order.
        cur_label = now.strftime('%b')
        cur_buckets = [b for b in data['monthly_trend'] if b['month'] == cur_label]
        assert sum(b['orders'] for b in cur_buckets) == 1
        assert sum(b['revenue'] for b in cur_buckets) == 1000
        # Old-year same-name month must not leak extra revenue into the window.
        assert data['total_revenue'] == 1000 + 500 + 7777
    finally:
        p.stop()


def test_malformed_and_unknown_handled():
    orders = [
        {'id': 'm1', 'artisan_id': 'a1', 'status': 'confirmed',
         'total_price': 'not-a-number', 'quantity': 'bad',
         'product_id': 'p1', 'product_title': 'T', 'created_at': 'not-a-date'},
        {'id': 'm2', 'artisan_id': 'a1', 'status': 'mystery_status',
         'total_price': 1000, 'quantity': 1,
         'product_id': 'p2', 'product_title': 'T2', 'created_at': cur_iso()},
        _order('confirmed', price=2000, qty=1, pid='good', title='Good'),
    ]
    client, p = _client_with_orders(orders)
    try:
        data = _summary(client)
        assert data['total_orders'] == 3
        assert data['order_status_counts'].get('mystery_status') == 1
        # Malformed money contributes 0, unknown excluded, good counted.
        assert data['total_revenue'] == 2000
        assert data['best_selling_product']['id'] == 'good'
    finally:
        p.stop()


def cur_iso():
    return datetime.now(timezone.utc).isoformat()


if __name__ == '__main__':
    test_zero_orders()
    print('PASS zero_orders')
    test_pending_excluded_from_revenue()
    print('PASS pending_excluded')
    test_cancelled_excluded_from_revenue()
    print('PASS cancelled_excluded')
    test_each_revenue_status_recognized()
    print('PASS each_revenue_status')
    test_paid_counts_as_completed()
    print('PASS paid_completed')
    test_aov_uses_recognized_count()
    print('PASS aov_denominator')
    test_best_seller_uses_recognized_only()
    print('PASS best_seller')
    test_no_sales_state_when_only_pipeline()
    print('PASS no_sales_state')
    test_monthly_excludes_pipeline_and_year_boundary()
    print('PASS monthly_year_boundary')
    test_malformed_and_unknown_handled()
    print('PASS malformed_unknown')
    print('ALL R2-05 ANALYTICS INTEGRITY TESTS PASSED')
