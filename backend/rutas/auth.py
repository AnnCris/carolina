# carolina/backend/rutas/auth.py
from flask import Blueprint, request, jsonify, current_app
from extensions import db
from modelos.usuario import Usuario
from modelos.rol import Rol
import bcrypt, uuid, os

bp_auth = Blueprint('auth', __name__)

@bp_auth.route('/login', methods=['POST'])
def login():
    datos = request.get_json() or {}
    email    = (datos.get('email')    or '').strip().lower()
    password = (datos.get('password') or '').strip()

    if not email or not password:
        return jsonify({'error': 'Correo y contraseña son requeridos'}), 400

    usuario = Usuario.query.filter_by(email=email).first()
    if not usuario:
        return jsonify({'error': 'Correo o contraseña incorrectos'}), 401

    hash_guardado = usuario.password_hash or ''
    if not (hash_guardado.startswith('$2b$') or hash_guardado.startswith('$2a$')):
        return jsonify({'error': 'Contraseña no válida. Contacta al administrador'}), 401

    try:
        pw_ok = bcrypt.checkpw(
            password.encode('utf-8'),
            hash_guardado.encode('utf-8')
        )
    except Exception as e:
        return jsonify({'error': f'Error al verificar: {str(e)}'}), 500

    if not pw_ok:
        return jsonify({'error': 'Correo o contraseña incorrectos'}), 401

    if not usuario.activo:
        return jsonify({'error': 'Usuario desactivado'}), 403

    # Devolvemos el ID como token — simple y funciona en web y móvil
    return jsonify({
        'token': str(usuario.id),
        'usuario': usuario.to_dict()
    }), 200


@bp_auth.route('/registro', methods=['POST'])
def registro():
    datos = request.get_json() or {}
    errores = {}

    nombre           = (datos.get('nombre')           or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    apellido_materno = (datos.get('apellido_materno') or '').strip()
    email            = (datos.get('email')            or '').strip().lower()
    password         = (datos.get('password')         or '')

    if len(nombre) < 2:
        errores['nombre'] = 'El nombre es requerido'
    if len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'El apellido paterno es requerido'
    if not email or '@' not in email:
        errores['email'] = 'Correo inválido'
    if len(password) < 8:
        errores['password'] = 'Mínimo 8 caracteres'

    if errores:
        return jsonify({'errores': errores}), 422

    if Usuario.query.filter_by(email=email).first():
        return jsonify({'errores': {'email': 'Este correo ya está registrado'}}), 422

    rol_vendedor = Rol.query.filter_by(nombre='vendedor').first()
    if not rol_vendedor:
        return jsonify({'error': 'Ejecuta crear_admin.py primero'}), 500

    hash_pw = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(12)).decode('utf-8')

    nuevo = Usuario(
        nombre=nombre,
        apellido_paterno=apellido_paterno,
        apellido_materno=apellido_materno or None,
        email=email,
        password_hash=hash_pw,
        rol_id=rol_vendedor.id,
        activo=True
    )
    db.session.add(nuevo)
    db.session.commit()

    return jsonify({
        'token': str(nuevo.id),
        'usuario': nuevo.to_dict()
    }), 201


@bp_auth.route('/logout', methods=['POST'])
def logout():
    return jsonify({'mensaje': 'Sesión cerrada'}), 200


@bp_auth.route('/perfil', methods=['GET'])
def perfil():
    from utilidades.permisos import obtener_usuario_actual
    usuario = obtener_usuario_actual()
    if not usuario:
        return jsonify({'error': 'No autenticado'}), 401
    return jsonify(usuario.to_dict())


@bp_auth.route('/perfil/foto', methods=['POST'])
def subir_foto_perfil():
    from utilidades.permisos import obtener_usuario_actual
    usuario = obtener_usuario_actual()
    if not usuario:
        return jsonify({'error': 'No autenticado'}), 401
    if 'foto' not in request.files:
        return jsonify({'error': 'No se envió imagen'}), 422
    archivo = request.files['foto']
    ext = archivo.filename.rsplit('.', 1)[-1].lower()
    if ext not in current_app.config['ALLOWED_EXTENSIONS']:
        return jsonify({'error': 'Formato no permitido'}), 422
    nombre_archivo = f"usuario_{uuid.uuid4().hex}.{ext}"
    archivo.save(os.path.join(current_app.config['UPLOAD_FOLDER'], nombre_archivo))
    usuario.foto = nombre_archivo
    db.session.commit()
    return jsonify({'foto': f'/api/subidas/{nombre_archivo}'}), 200