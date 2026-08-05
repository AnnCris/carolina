-- ============================================================================
-- Distribuidora de Quesos Carolina — Script de creación de base de datos
-- PostgreSQL 18 (también funciona en PostgreSQL 13+)
--
-- Este script recrea TODO el esquema del proyecto desde cero (todas las
-- tablas actuales: productos, ventas, cobranzas, devoluciones, pedidos,
-- compras, inventario, usuarios con nombre_usuario, etc.) y siembra los
-- datos mínimos para poder entrar a la app por primera vez: los 3 roles
-- del sistema y un usuario administrador.
--
-- CÓMO USARLO
-- -----------
-- 1) Crea la base de datos vacía (si no existe todavía). Desde una
--    terminal, conectado como el superusuario (normalmente "postgres"):
--
--        CREATE DATABASE carolina_db;
--
--    (puedes hacerlo con psql: `psql -U postgres -c "CREATE DATABASE carolina_db;"`)
--
-- 2) Ejecuta este archivo completo contra esa base de datos:
--
--        psql -U postgres -d carolina_db -f crear_base_datos_carolina.sql
--
--    (en pgAdmin: abre una Query Tool contra "carolina_db" y pega/ejecuta
--    todo este archivo)
--
-- 3) Ya puedes iniciar el backend (`python app.py`) y entrar a la app con:
--        usuario:    admin
--        contraseña: Admin1234
--
--    IMPORTANTE: cambia esa contraseña apenas entres (Perfil o el panel de
--    Usuarios), es una contraseña de ejemplo conocida por cualquiera que
--    lea este archivo.
--
-- Si en lugar de esto prefieres que el propio backend cree las tablas por
-- ti (equivalente a este script), puedes seguir usando
-- `python crear_admin.py` — este .sql es una alternativa que no depende de
-- que Python/SQLAlchemy puedan conectarse correctamente a Postgres.
-- ============================================================================


-- ============================================================================
-- 1) TABLAS
-- ============================================================================

CREATE TABLE public.categorias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text
);

CREATE TABLE public.clientes (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    ci_nit character varying(50),
    telefono character varying(20),
    email character varying(150),
    direccion text,
    activo boolean
);

CREATE TABLE public.roles (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    permisos json
);

CREATE TABLE public.usuarios (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido_paterno character varying(100) NOT NULL,
    apellido_materno character varying(100),
    nombre_usuario character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    rol_id integer,
    foto character varying(255),
    activo boolean,
    created_at timestamp without time zone
);

CREATE TABLE public.marcas (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text
);

CREATE TABLE public.proveedores (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    nit character varying(50),
    telefono character varying(20),
    email character varying(150),
    direccion text,
    contacto character varying(100),
    activo boolean
);

CREATE TABLE public.productos (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text,
    categoria_id integer,
    marca_id integer,
    foto character varying(255),
    tipo_peso character varying(20),
    peso_gramos numeric(10,3),
    unidad character varying(20),
    activo boolean
);

-- Relación muchos-a-muchos: qué proveedores abastecen qué productos
CREATE TABLE public.proveedor_productos (
    proveedor_id integer NOT NULL,
    producto_id integer NOT NULL
);

CREATE TABLE public.inventario (
    id integer NOT NULL,
    producto_id integer,
    stock_actual numeric(12,2),
    stock_minimo numeric(12,2),
    stock_maximo numeric(12,2),
    metodo_valuacion character varying(10),
    ultima_entrada timestamp without time zone,
    ultima_salida timestamp without time zone,
    updated_at timestamp without time zone
);

CREATE TABLE public.movimientos_inventario (
    id integer NOT NULL,
    inventario_id integer,
    producto_id integer,
    tipo character varying(20),
    cantidad numeric(12,2),
    referencia_tipo character varying(30),
    referencia_id integer,
    nota text,
    fecha timestamp without time zone,
    usuario_id integer
);

CREATE TABLE public.precios (
    id integer NOT NULL,
    producto_id integer,
    tipo character varying(20) NOT NULL,
    proveedor_id integer,
    precio numeric(12,2) NOT NULL,
    moneda character varying(5),
    vigente_desde date,
    activo boolean
);

CREATE TABLE public.compras (
    id integer NOT NULL,
    proveedor_id integer,
    usuario_id integer,
    fecha timestamp without time zone,
    total numeric(12,2),
    estado character varying(30),
    nota text,
    imagen_factura character varying(255)
);

CREATE TABLE public.detalle_compras (
    id integer NOT NULL,
    compra_id integer,
    producto_id integer,
    cantidad numeric(10,3),
    peso_total_kg numeric(10,3),
    precio_unitario numeric(12,2),
    subtotal numeric(12,2),
    unidades_x_caja integer,
    num_cajas integer,
    tipo_precio character varying(20)
);

CREATE TABLE public.pedidos (
    id integer NOT NULL,
    cliente_id integer,
    usuario_id integer,
    fecha timestamp without time zone,
    fecha_entrega date,
    estado character varying(30),
    total_estimado numeric(12,2),
    nota text
);

CREATE TABLE public.ventas (
    id integer NOT NULL,
    cliente_id integer,
    usuario_id integer,
    pedido_id integer,
    fecha timestamp without time zone,
    total numeric(12,2),
    descuento numeric(12,2),
    estado character varying(30),
    nota text,
    numero_recibo character varying(50)
);

CREATE TABLE public.devoluciones (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    venta_id integer,
    usuario_id integer,
    fecha timestamp without time zone,
    estado character varying(20),
    nota text,
    fecha_resolucion timestamp without time zone,
    venta_resolucion_id integer
);

CREATE TABLE public.detalle_pedidos (
    id integer NOT NULL,
    pedido_id integer,
    producto_id integer,
    cantidad numeric(10,2),
    devolucion_id integer
);

CREATE TABLE public.detalle_ventas (
    id integer NOT NULL,
    venta_id integer,
    producto_id integer,
    cantidad numeric(10,3),
    precio_unitario numeric(12,2),
    subtotal numeric(12,2),
    peso_kg numeric(10,3),
    precio_editado boolean,
    devolucion_id integer
);

CREATE TABLE public.detalle_devoluciones (
    id integer NOT NULL,
    devolucion_id integer,
    producto_id integer,
    cantidad numeric(10,3),
    motivo character varying(30),
    motivo_detalle text
);

CREATE TABLE public.cobranzas (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    usuario_id integer,
    fecha timestamp without time zone,
    metodo_pago character varying(20) NOT NULL,
    monto_total numeric(12,2) NOT NULL,
    nota text
);

CREATE TABLE public.detalle_cobranzas (
    id integer NOT NULL,
    cobranza_id integer,
    venta_id integer NOT NULL,
    monto numeric(12,2) NOT NULL
);


-- ============================================================================
-- 2) SECUENCIAS (autoincrement de cada id) + valor por defecto
-- ============================================================================

CREATE SEQUENCE public.categorias_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.categorias_id_seq OWNED BY public.categorias.id;
ALTER TABLE ONLY public.categorias ALTER COLUMN id SET DEFAULT nextval('public.categorias_id_seq'::regclass);

CREATE SEQUENCE public.clientes_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.clientes_id_seq OWNED BY public.clientes.id;
ALTER TABLE ONLY public.clientes ALTER COLUMN id SET DEFAULT nextval('public.clientes_id_seq'::regclass);

CREATE SEQUENCE public.roles_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;
ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);

CREATE SEQUENCE public.usuarios_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;
ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);

CREATE SEQUENCE public.marcas_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.marcas_id_seq OWNED BY public.marcas.id;
ALTER TABLE ONLY public.marcas ALTER COLUMN id SET DEFAULT nextval('public.marcas_id_seq'::regclass);

CREATE SEQUENCE public.proveedores_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.proveedores_id_seq OWNED BY public.proveedores.id;
ALTER TABLE ONLY public.proveedores ALTER COLUMN id SET DEFAULT nextval('public.proveedores_id_seq'::regclass);

CREATE SEQUENCE public.productos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.productos_id_seq OWNED BY public.productos.id;
ALTER TABLE ONLY public.productos ALTER COLUMN id SET DEFAULT nextval('public.productos_id_seq'::regclass);

CREATE SEQUENCE public.inventario_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.inventario_id_seq OWNED BY public.inventario.id;
ALTER TABLE ONLY public.inventario ALTER COLUMN id SET DEFAULT nextval('public.inventario_id_seq'::regclass);

CREATE SEQUENCE public.movimientos_inventario_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.movimientos_inventario_id_seq OWNED BY public.movimientos_inventario.id;
ALTER TABLE ONLY public.movimientos_inventario ALTER COLUMN id SET DEFAULT nextval('public.movimientos_inventario_id_seq'::regclass);

CREATE SEQUENCE public.precios_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.precios_id_seq OWNED BY public.precios.id;
ALTER TABLE ONLY public.precios ALTER COLUMN id SET DEFAULT nextval('public.precios_id_seq'::regclass);

CREATE SEQUENCE public.compras_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.compras_id_seq OWNED BY public.compras.id;
ALTER TABLE ONLY public.compras ALTER COLUMN id SET DEFAULT nextval('public.compras_id_seq'::regclass);

CREATE SEQUENCE public.detalle_compras_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.detalle_compras_id_seq OWNED BY public.detalle_compras.id;
ALTER TABLE ONLY public.detalle_compras ALTER COLUMN id SET DEFAULT nextval('public.detalle_compras_id_seq'::regclass);

CREATE SEQUENCE public.pedidos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.pedidos_id_seq OWNED BY public.pedidos.id;
ALTER TABLE ONLY public.pedidos ALTER COLUMN id SET DEFAULT nextval('public.pedidos_id_seq'::regclass);

CREATE SEQUENCE public.ventas_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.ventas_id_seq OWNED BY public.ventas.id;
ALTER TABLE ONLY public.ventas ALTER COLUMN id SET DEFAULT nextval('public.ventas_id_seq'::regclass);

CREATE SEQUENCE public.devoluciones_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.devoluciones_id_seq OWNED BY public.devoluciones.id;
ALTER TABLE ONLY public.devoluciones ALTER COLUMN id SET DEFAULT nextval('public.devoluciones_id_seq'::regclass);

CREATE SEQUENCE public.detalle_pedidos_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.detalle_pedidos_id_seq OWNED BY public.detalle_pedidos.id;
ALTER TABLE ONLY public.detalle_pedidos ALTER COLUMN id SET DEFAULT nextval('public.detalle_pedidos_id_seq'::regclass);

CREATE SEQUENCE public.detalle_ventas_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.detalle_ventas_id_seq OWNED BY public.detalle_ventas.id;
ALTER TABLE ONLY public.detalle_ventas ALTER COLUMN id SET DEFAULT nextval('public.detalle_ventas_id_seq'::regclass);

CREATE SEQUENCE public.detalle_devoluciones_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.detalle_devoluciones_id_seq OWNED BY public.detalle_devoluciones.id;
ALTER TABLE ONLY public.detalle_devoluciones ALTER COLUMN id SET DEFAULT nextval('public.detalle_devoluciones_id_seq'::regclass);

CREATE SEQUENCE public.cobranzas_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.cobranzas_id_seq OWNED BY public.cobranzas.id;
ALTER TABLE ONLY public.cobranzas ALTER COLUMN id SET DEFAULT nextval('public.cobranzas_id_seq'::regclass);

CREATE SEQUENCE public.detalle_cobranzas_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.detalle_cobranzas_id_seq OWNED BY public.detalle_cobranzas.id;
ALTER TABLE ONLY public.detalle_cobranzas ALTER COLUMN id SET DEFAULT nextval('public.detalle_cobranzas_id_seq'::regclass);


-- ============================================================================
-- 3) LLAVES PRIMARIAS Y RESTRICCIONES ÚNICAS
-- ============================================================================

ALTER TABLE ONLY public.categorias ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.clientes ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.roles ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.roles ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY public.usuarios ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.usuarios ADD CONSTRAINT usuarios_nombre_usuario_key UNIQUE (nombre_usuario);
ALTER TABLE ONLY public.marcas ADD CONSTRAINT marcas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.proveedores ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.productos ADD CONSTRAINT productos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.proveedor_productos ADD CONSTRAINT proveedor_productos_pkey PRIMARY KEY (proveedor_id, producto_id);
ALTER TABLE ONLY public.inventario ADD CONSTRAINT inventario_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.inventario ADD CONSTRAINT inventario_producto_id_key UNIQUE (producto_id);
ALTER TABLE ONLY public.movimientos_inventario ADD CONSTRAINT movimientos_inventario_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.precios ADD CONSTRAINT precios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.compras ADD CONSTRAINT compras_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.detalle_compras ADD CONSTRAINT detalle_compras_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.pedidos ADD CONSTRAINT pedidos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.ventas ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.ventas ADD CONSTRAINT ventas_numero_recibo_key UNIQUE (numero_recibo);
ALTER TABLE ONLY public.devoluciones ADD CONSTRAINT devoluciones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.detalle_pedidos ADD CONSTRAINT detalle_pedidos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.detalle_ventas ADD CONSTRAINT detalle_ventas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.detalle_devoluciones ADD CONSTRAINT detalle_devoluciones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.cobranzas ADD CONSTRAINT cobranzas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.detalle_cobranzas ADD CONSTRAINT detalle_cobranzas_pkey PRIMARY KEY (id);


-- ============================================================================
-- 4) LLAVES FORÁNEAS
-- ============================================================================

ALTER TABLE ONLY public.usuarios ADD CONSTRAINT usuarios_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);

ALTER TABLE ONLY public.productos ADD CONSTRAINT productos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);
ALTER TABLE ONLY public.productos ADD CONSTRAINT productos_marca_id_fkey FOREIGN KEY (marca_id) REFERENCES public.marcas(id);

ALTER TABLE ONLY public.proveedor_productos ADD CONSTRAINT proveedor_productos_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);
ALTER TABLE ONLY public.proveedor_productos ADD CONSTRAINT proveedor_productos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);

ALTER TABLE ONLY public.inventario ADD CONSTRAINT inventario_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);

ALTER TABLE ONLY public.movimientos_inventario ADD CONSTRAINT movimientos_inventario_inventario_id_fkey FOREIGN KEY (inventario_id) REFERENCES public.inventario(id);
ALTER TABLE ONLY public.movimientos_inventario ADD CONSTRAINT movimientos_inventario_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);
ALTER TABLE ONLY public.movimientos_inventario ADD CONSTRAINT movimientos_inventario_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);

ALTER TABLE ONLY public.precios ADD CONSTRAINT precios_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);
ALTER TABLE ONLY public.precios ADD CONSTRAINT precios_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);

ALTER TABLE ONLY public.compras ADD CONSTRAINT compras_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);
ALTER TABLE ONLY public.compras ADD CONSTRAINT compras_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);

ALTER TABLE ONLY public.detalle_compras ADD CONSTRAINT detalle_compras_compra_id_fkey FOREIGN KEY (compra_id) REFERENCES public.compras(id);
ALTER TABLE ONLY public.detalle_compras ADD CONSTRAINT detalle_compras_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);

ALTER TABLE ONLY public.pedidos ADD CONSTRAINT pedidos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);
ALTER TABLE ONLY public.pedidos ADD CONSTRAINT pedidos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);

ALTER TABLE ONLY public.ventas ADD CONSTRAINT ventas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);
ALTER TABLE ONLY public.ventas ADD CONSTRAINT ventas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);
ALTER TABLE ONLY public.ventas ADD CONSTRAINT ventas_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id);

ALTER TABLE ONLY public.devoluciones ADD CONSTRAINT devoluciones_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);
ALTER TABLE ONLY public.devoluciones ADD CONSTRAINT devoluciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);
ALTER TABLE ONLY public.devoluciones ADD CONSTRAINT devoluciones_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES public.ventas(id);
ALTER TABLE ONLY public.devoluciones ADD CONSTRAINT devoluciones_venta_resolucion_id_fkey FOREIGN KEY (venta_resolucion_id) REFERENCES public.ventas(id);

ALTER TABLE ONLY public.detalle_pedidos ADD CONSTRAINT detalle_pedidos_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id);
ALTER TABLE ONLY public.detalle_pedidos ADD CONSTRAINT detalle_pedidos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);
ALTER TABLE ONLY public.detalle_pedidos ADD CONSTRAINT detalle_pedidos_devolucion_id_fkey FOREIGN KEY (devolucion_id) REFERENCES public.devoluciones(id);

ALTER TABLE ONLY public.detalle_ventas ADD CONSTRAINT detalle_ventas_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES public.ventas(id);
ALTER TABLE ONLY public.detalle_ventas ADD CONSTRAINT detalle_ventas_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);
ALTER TABLE ONLY public.detalle_ventas ADD CONSTRAINT detalle_ventas_devolucion_id_fkey FOREIGN KEY (devolucion_id) REFERENCES public.devoluciones(id);

ALTER TABLE ONLY public.detalle_devoluciones ADD CONSTRAINT detalle_devoluciones_devolucion_id_fkey FOREIGN KEY (devolucion_id) REFERENCES public.devoluciones(id);
ALTER TABLE ONLY public.detalle_devoluciones ADD CONSTRAINT detalle_devoluciones_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);

ALTER TABLE ONLY public.cobranzas ADD CONSTRAINT cobranzas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);
ALTER TABLE ONLY public.cobranzas ADD CONSTRAINT cobranzas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);

ALTER TABLE ONLY public.detalle_cobranzas ADD CONSTRAINT detalle_cobranzas_cobranza_id_fkey FOREIGN KEY (cobranza_id) REFERENCES public.cobranzas(id);
ALTER TABLE ONLY public.detalle_cobranzas ADD CONSTRAINT detalle_cobranzas_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


-- ============================================================================
-- 5) DATOS INICIALES: roles del sistema
-- (mismos permisos que utilidades/permisos.py -> PERMISOS_ROL)
-- ============================================================================

INSERT INTO public.roles (nombre, permisos) VALUES
    ('admin', '{"todo": true}'),
    ('vendedor', '{"ventas": true, "pedidos": true, "clientes": true, "devoluciones": true, "cobranzas": true, "productos_ver": true}'),
    ('almacenero', '{"inventario": true, "compras": true, "productos": true, "productos_ver": true, "proveedores": true, "devoluciones": true}');


-- ============================================================================
-- 6) USUARIO ADMINISTRADOR INICIAL
--
-- Usuario:    admin
-- Contraseña: Admin1234
--
-- El hash de abajo corresponde exactamente a "Admin1234" con bcrypt
-- (costo 12), verificado antes de entregarte este archivo. Inicia sesión
-- con estos datos y CAMBIA LA CONTRASEÑA de inmediato desde la app.
--
-- Si prefieres definir tu propia contraseña desde ya en vez de usar la de
-- ejemplo, genera tu propio hash con Python (con el venv del backend
-- activado) y reemplaza el valor de password_hash:
--
--     python -c "import bcrypt; print(bcrypt.hashpw(b'TU_CONTRASEÑA', bcrypt.gensalt(12)).decode())"
-- ============================================================================

INSERT INTO public.usuarios
    (nombre, apellido_paterno, apellido_materno, nombre_usuario, password_hash, rol_id, activo)
VALUES
    ('Administrador', 'Sistema', NULL, 'admin',
     '$2b$12$8HcQ.IW8ioOyHGCMNIjHme8f43oL1uhWn3NQVi3MefphNcVI1/lwK',
     (SELECT id FROM public.roles WHERE nombre = 'admin'),
     true);


-- ============================================================================
-- Listo. Verifica que todo quedó bien con:
--   SELECT nombre_usuario, activo FROM usuarios;
--   SELECT nombre, permisos FROM roles;
-- ============================================================================
