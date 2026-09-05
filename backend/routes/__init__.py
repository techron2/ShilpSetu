from flask import Blueprint
from .health import health_bp
from .catalog import catalog_bp
from .orders import orders_bp

def register_routes(app):
    """Registers all route blueprints with the Flask application."""
    app.register_blueprint(health_bp, url_prefix='/api')
    app.register_blueprint(catalog_bp, url_prefix='/api/catalog')
    app.register_blueprint(orders_bp, url_prefix='/api/orders')
