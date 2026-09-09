from .health import health_bp
from .catalog import catalog_bp
from .orders import orders_bp
from .products import products_bp
from .users import users_bp
from .pricing import pricing_bp
from .assistant import assistant_bp
from .matching import matching_bp
from .rfq import rfq_bp
from .passport import passport_bp, _HTML_TEMPLATE, _build_passport_payload
from .analytics import analytics_bp
from .promo import promo_bp
from .clusters import clusters_bp
from flask import render_template_string


def register_routes(app):
    """Registers all route blueprints with the Flask application."""
    app.register_blueprint(health_bp,    url_prefix='/api')
    app.register_blueprint(catalog_bp,   url_prefix='/api/catalog')
    app.register_blueprint(orders_bp,    url_prefix='/api/orders')
    app.register_blueprint(products_bp,  url_prefix='/api/products')
    app.register_blueprint(users_bp,     url_prefix='/api/users')
    app.register_blueprint(pricing_bp,   url_prefix='/api/pricing')
    app.register_blueprint(assistant_bp, url_prefix='/api/assistant')
    app.register_blueprint(matching_bp,  url_prefix='/api/matching')
    app.register_blueprint(rfq_bp,       url_prefix='/api/rfq')
    app.register_blueprint(passport_bp,  url_prefix='/api/passport')
    app.register_blueprint(analytics_bp, url_prefix='/api/analytics')
    app.register_blueprint(promo_bp,      url_prefix='/api/promo')
    app.register_blueprint(clusters_bp,  url_prefix='/api/clusters')

    # Direct web view route for QR code scanner (/passport/<product_id>)
    @app.route('/passport/<product_id>', methods=['GET'])
    def public_passport_view(product_id):
        passport = _build_passport_payload(product_id)
        return render_template_string(_HTML_TEMPLATE, passport=passport)
