from .health import health_bp
from .catalog import catalog_bp
from .orders import orders_bp
from .products import products_bp
from .users import users_bp
from .pricing import pricing_bp
from .assistant import assistant_bp


def register_routes(app):
    """Registers all route blueprints with the Flask application."""
    app.register_blueprint(health_bp,    url_prefix='/api')
    app.register_blueprint(catalog_bp,   url_prefix='/api/catalog')
    app.register_blueprint(orders_bp,    url_prefix='/api/orders')
    app.register_blueprint(products_bp,  url_prefix='/api/products')
    app.register_blueprint(users_bp,     url_prefix='/api/users')
    app.register_blueprint(pricing_bp,   url_prefix='/api/pricing')
    app.register_blueprint(assistant_bp, url_prefix='/api/assistant')
