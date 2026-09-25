import unittest
from unittest.mock import patch

from flask import Flask

from routes.analytics import analytics_bp
from routes.users import calculate_trust_score


class _Snapshot:
    def __init__(self, data):
        self._data = data
        self.id = data.get('id', 'order')

    def to_dict(self):
        return self._data


class _Query:
    def __init__(self, rows):
        self._rows = rows

    def where(self, *_args, **_kwargs):
        return self

    def stream(self):
        return [_Snapshot(row) for row in self._rows]


class _MissingUserRef:
    class _Missing:
        exists = False

    def get(self):
        return self._Missing()


class _Collection(_Query):
    def document(self, _uid):
        return _MissingUserRef()


class _FakeDb:
    def __init__(self, orders):
        self._orders = orders

    def collection(self, name):
        return _Collection(self._orders if name == 'orders' else [])


class TrustScoreIntegrityTest(unittest.TestCase):
    def test_new_artisan_has_no_invented_trust_history(self):
        result = calculate_trust_score('new-artisan', db=_FakeDb([]))

        self.assertFalse(result['has_history'])
        self.assertIsNone(result['trust_score'])
        self.assertIsNone(result['rating'])
        self.assertIsNone(result['completion_rate_pct'])
        self.assertEqual(result['badge'], 'Building history')

    def test_trust_score_uses_finished_orders_and_real_ratings(self):
        result = calculate_trust_score(
            'experienced-artisan',
            db=_FakeDb([
                {'status': 'delivered', 'rating': 5},
                {'status': 'cancelled', 'rating': 3},
                {'status': 'pending'},
            ]),
        )

        self.assertTrue(result['has_history'])
        self.assertEqual(result['completion_rate_pct'], 50)
        self.assertEqual(result['rating'], 4.0)
        self.assertEqual(result['trust_score'], 3.2)
        self.assertEqual(result['total_orders'], 3)


class AnalyticsIntegrityTest(unittest.TestCase):
    def setUp(self):
        app = Flask(__name__)
        app.register_blueprint(analytics_bp, url_prefix='/api/analytics')
        self.client = app.test_client()

    def _summary(self, orders):
        with patch(
            'routes.analytics.get_firestore_client',
            return_value=_FakeDb(orders),
        ):
            response = self.client.get(
                '/api/analytics/summary?artisan_id=test-artisan',
            )
        self.assertEqual(response.status_code, 200)
        return response.get_json()

    def test_live_summary_excludes_pending_and_includes_paid_revenue(self):
        result = self._summary([
            {
                'id': 'pending',
                'status': 'pending',
                'total_price': 100,
                'quantity': 1,
                'created_at': '2026-09-01T00:00:00+00:00',
            },
            {
                'id': 'paid',
                'status': 'paid',
                'total_price': 200,
                'quantity': 1,
                'created_at': '2026-09-02T00:00:00+00:00',
            },
            {
                'id': 'delivered',
                'status': 'delivered',
                'total_price': 300,
                'quantity': 1,
                'created_at': '2026-08-15T00:00:00+00:00',
            },
            {
                'id': 'cancelled',
                'status': 'cancelled',
                'total_price': 500,
                'quantity': 1,
                'created_at': '2026-09-03T00:00:00+00:00',
            },
        ])

        self.assertEqual(result['source'], 'firestore')
        self.assertEqual(result['data']['total_orders'], 4)
        self.assertEqual(result['data']['total_revenue'], 500)
        self.assertEqual(result['data']['revenue_this_month'], 200)
        self.assertEqual(result['data']['revenue_last_month'], 300)

    def test_sparse_live_history_is_not_filled_with_sample_revenue(self):
        result = self._summary([
            {
                'id': 'confirmed',
                'status': 'confirmed',
                'total_price': 700,
                'quantity': 1,
                'created_at': 'not-a-date',
            },
        ])

        data = result['data']
        self.assertEqual(result['source'], 'firestore')
        self.assertEqual(data['total_revenue'], 700)
        self.assertEqual(data['revenue_this_month'], 0)
        self.assertEqual(data['revenue_last_month'], 0)
        self.assertTrue(all(point['revenue'] == 0 for point in data['monthly_trend']))


if __name__ == '__main__':
    unittest.main()
