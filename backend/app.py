# carolina/backend/app.py
from flask import Flask, request, send_from_directory
from flask_cors import CORS
from extensions import db
from utilidades.auditoria import registrar_desde_request
import os

def crear_app():
    app = Flask(__name__)
    app.config.from_object('config.Config')

    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

    db.init_app(app)

    # CORS: permitir CUALQUIER origen local
    CORS(app,
         resources={r"/api/*": {"origins": "*"}},
         supports_credentials=False)

    from rutas.auth import bp_auth
    from rutas.usuarios import bp_usuarios
    from rutas.productos import bp_productos
    from rutas.categorias import bp_categorias
    from rutas.marcas import bp_marcas
    from rutas.proveedores import bp_proveedores
    from rutas.clientes import bp_clientes
    from rutas.compras import bp_compras
    from rutas.ventas import bp_ventas
    from rutas.inventario import bp_inventario
    from rutas.pedidos import bp_pedidos
    from rutas.devoluciones import bp_devoluciones
    from rutas.precios import bp_precios
    from rutas.cobranzas import bp_cobranzas
    from rutas.dashboard import bp_dashboard
    from rutas.auditoria import bp_auditoria

    for bp in [bp_auth, bp_usuarios, bp_productos, bp_categorias,
               bp_marcas, bp_proveedores, bp_clientes, bp_compras,
               bp_ventas, bp_inventario, bp_pedidos, bp_devoluciones,
               bp_precios, bp_cobranzas, bp_dashboard, bp_auditoria]:
        app.register_blueprint(bp, url_prefix='/api')

    @app.route('/api/subidas/<nombre_archivo>')
    def subidas(nombre_archivo):
        return send_from_directory(app.config['UPLOAD_FOLDER'], nombre_archivo)

    # Auditoría: registra automáticamente cada creación/edición/eliminación
    # (y login/logout) de cualquier módulo, sin tener que tocar cada ruta.
    @app.after_request
    def _auditar(response):
        try:
            registrar_desde_request(request, response)
        except Exception:
            db.session.rollback()
        return response

    with app.app_context():
        db.create_all()

    return app

if __name__ == '__main__':
    app = crear_app()
    app.run(debug=True, port=5000)