-- =================================================================
-- ECOLAP BETA - Script SQL para MySQL Workbench
-- Base de datos: ecolap_db
-- Charset: utf8mb4 / Collation: utf8mb4_unicode_ci
-- Adaptado a los módulos: Login, Mapa, Juegos, Aprender y Recolección
-- =================================================================
DROP DATABASE IF EXISTS ecolap_db;
-- Crear la base de datos con charset utf8mb4 para soportar emojis y caracteres especiales
CREATE DATABASE ecolap_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ecolap_db;

-- =================================================================
-- 1. TABLA: roles
-- -----------------------------------------------------------------
-- Almacena los tipos de usuario del sistema ECOLAP.
-- Se usa en el módulo de login para asignar permisos.
-- =================================================================
CREATE TABLE roles (
    id_rol        INT          NOT NULL AUTO_INCREMENT,
    nombre_rol    VARCHAR(20)  NOT NULL UNIQUE,    -- USUARIO, RECOLECTOR, ADMINISTRADOR
    descripcion   VARCHAR(150) NULL,
    PRIMARY KEY (id_rol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 2. TABLA: usuarios
-- -----------------------------------------------------------------
-- Tabla principal de usuarios; alimenta login.html y la gestión
-- de perfil. Incluye puntos_acumulados para el sistema de
-- recompensas de ECOLAP.
-- =================================================================
CREATE TABLE usuarios (
    id_usuario          INT          NOT NULL AUTO_INCREMENT,
    nombre              VARCHAR(100) NOT NULL,
    email               VARCHAR(150) NOT NULL UNIQUE,    -- Único para evitar duplicados
    password_hash       VARCHAR(255) NOT NULL,           -- Hash bcrypt/argon2
    telefono            VARCHAR(20)  NULL,
    id_rol              INT          NOT NULL,           -- FK hacia roles
    puntos_acumulados   INT          NOT NULL DEFAULT 0, -- Moneda virtual ECOLAP
    fecha_registro      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado              ENUM('activo', 'inactivo') NOT NULL DEFAULT 'activo',
    PRIMARY KEY (id_usuario),
    CONSTRAINT fk_usuarios_roles
        FOREIGN KEY (id_rol) REFERENCES roles (id_rol)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 3. TABLA: puntos_reciclaje
-- -----------------------------------------------------------------
-- Puntos físicos visibles en el mapa de mapa.html. Cada punto
-- tiene coordenadas geográficas y un tipo de material aceptado.
-- =================================================================
CREATE TABLE puntos_reciclaje (
    id_punto            INT             NOT NULL AUTO_INCREMENT,
    nombre              VARCHAR(120)    NOT NULL,
    direccion           VARCHAR(255)    NOT NULL,
    latitud             DECIMAL(10, 8)  NOT NULL,
    longitud            DECIMAL(11, 8)  NOT NULL,
    tipo_material       ENUM('Plástico', 'Papel', 'Vidrio', 'Orgánico', 'General') NOT NULL DEFAULT 'General',
    id_administrador    INT             NULL,            -- Admin que registró el punto
    fecha_creacion      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado              ENUM('activo', 'inactivo') NOT NULL DEFAULT 'activo',
    PRIMARY KEY (id_punto),
    CONSTRAINT fk_puntos_administrador
        FOREIGN KEY (id_administrador) REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 4. TABLA: solicitudes_recoleccion
-- -----------------------------------------------------------------
-- Solicitudes que los usuarios envían para recolección a domicilio.
-- Conecta con el módulo de mapa y el sistema de tracking.
-- =================================================================
CREATE TABLE solicitudes_recoleccion (
    id_solicitud        INT             NOT NULL AUTO_INCREMENT,
    id_usuario          INT             NOT NULL,                -- Usuario que solicita
    id_recolector       INT             NULL,                    -- Recolector asignado (NULL hasta aceptación)
    direccion           VARCHAR(255)    NOT NULL,
    latitud             DECIMAL(10, 8)  NULL,
    longitud            DECIMAL(11, 8)  NULL,
    tipo_residuo        ENUM('Plástico', 'Papel', 'Vidrio', 'Orgánico', 'General') NOT NULL DEFAULT 'General',
    estado_solicitud    ENUM('Pendiente', 'Aceptada', 'En Camino', 'Completada', 'Cancelada') NOT NULL DEFAULT 'Pendiente',
    fecha_solicitud     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_recoleccion   DATETIME        NULL,
    PRIMARY KEY (id_solicitud),
    -- El usuario que solicita NO debe eliminarse si tiene solicitudes (RESTRICT)
    CONSTRAINT fk_solicitudes_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- El recolector puede eliminarse; sus solicitudes quedan con id_recolector NULL
    CONSTRAINT fk_solicitudes_recolector
        FOREIGN KEY (id_recolector) REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 5. TABLA: observaciones_recoleccion
-- -----------------------------------------------------------------
-- Comentarios/notas que dejan los recolectores al momento de
-- completar una solicitud.
-- =================================================================
CREATE TABLE observaciones_recoleccion (
    id_observacion  INT       NOT NULL AUTO_INCREMENT,
    id_solicitud    INT       NOT NULL,
    id_recolector   INT       NOT NULL,
    comentario      TEXT      NOT NULL,
    fecha           DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_observacion),
    CONSTRAINT fk_obs_solicitud
        FOREIGN KEY (id_solicitud) REFERENCES solicitudes_recoleccion (id_solicitud)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_obs_recolector
        FOREIGN KEY (id_recolector) REFERENCES usuarios (id_usuario)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 6. TABLA: recompensas
-- -----------------------------------------------------------------
-- Catálogo de premios canjeables por puntos ECOLAP en la
-- pantalla juegos.html / sección de recompensas.
-- =================================================================
CREATE TABLE recompensas (
    id_recompensa       INT          NOT NULL AUTO_INCREMENT,
    titulo              VARCHAR(120) NOT NULL,
    descripcion         TEXT         NULL,
    puntos_requeridos   INT          NOT NULL DEFAULT 0,
    stock               INT          NOT NULL DEFAULT 0,
    estado              ENUM('disponible', 'agotado', 'inactivo') NOT NULL DEFAULT 'disponible',
    PRIMARY KEY (id_recompensa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 7. TABLA: historial_canjes
-- -----------------------------------------------------------------
-- Bitácora de canjes: cuándo un usuario canjeó puntos por
-- una recompensa específica.
-- =================================================================
CREATE TABLE historial_canjes (
    id_canje            INT       NOT NULL AUTO_INCREMENT,
    id_usuario          INT       NOT NULL,
    id_recompensa       INT       NOT NULL,
    puntos_utilizados   INT       NOT NULL,
    fecha_canje         DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_canje),
    CONSTRAINT fk_canjes_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_canjes_recompensa
        FOREIGN KEY (id_recompensa) REFERENCES recompensas (id_recompensa)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 8. TABLA: contenido_educativo
-- -----------------------------------------------------------------
-- Material educativo mostrado en la pantalla aprende.html:
-- Tips, Tutoriales y Guías ECOLAP.
-- =================================================================
CREATE TABLE contenido_educativo (
    id_contenido        INT          NOT NULL AUTO_INCREMENT,
    titulo              VARCHAR(150) NOT NULL,
    categoria           ENUM('Tips', 'Tutoriales', 'Guías') NOT NULL,
    descripcion         TEXT         NULL,
    url_media           VARCHAR(500) NULL,                 -- URL de imagen/video
    id_administrador    INT          NULL,                 -- Admin que publicó
    fecha_publicacion   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado              ENUM('publicado', 'borrador') NOT NULL DEFAULT 'publicado',
    PRIMARY KEY (id_contenido),
    CONSTRAINT fk_contenido_admin
        FOREIGN KEY (id_administrador) REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- 9. TABLA: juegos
-- -----------------------------------------------------------------
-- Registro de las partidas de los minijuegos ECOLAP. Permite
-- otorgar puntos a los usuarios según su desempeño.
-- =================================================================
CREATE TABLE juegos (
    id_juego            INT          NOT NULL AUTO_INCREMENT,
    id_usuario          INT          NOT NULL,
    nombre_juego        VARCHAR(100) NOT NULL,              -- Fast-Sorter, Misión Urbana, etc.
    puntaje             INT          NOT NULL DEFAULT 0,
    puntos_otorgados    INT          NOT NULL DEFAULT 0,     -- Puntos ECOLAP ganados en la partida
    fecha_partida       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_juego),
    CONSTRAINT fk_juegos_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE
        ON UPDATE CASCADE
	
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =================================================================
-- 10. TABLA: ubicacion_recolectores
-- -----------------------------------------------------------------
-- Almacena las coordenadas GPS enviadas periódicamente desde el 
-- celular del recolector (Google Maps API / Geolocation API).
-- Soporta el rastreo en tiempo real para solicitudes y rutas públicas.
-- =================================================================
CREATE TABLE ubicacion_recolectores (
    id_ubicacion    INT             NOT NULL AUTO_INCREMENT,
    id_recolector   INT             NOT NULL,                -- Recolector transmitiendo GPS
    id_solicitud    INT             NULL,                    -- Opcional: Vinculado a recolección 'En Camino'
    latitud         DECIMAL(10, 8)  NOT NULL,                -- Coordenada de latitud del dispositivo
    longitud        DECIMAL(11, 8)  NOT NULL,                -- Coordenada de longitud del dispositivo
    fecha_hora      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_ubicacion),
    CONSTRAINT fk_ubicacion_recolector
        FOREIGN KEY (id_recolector) REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_ubicacion_solicitud
        FOREIGN KEY (id_solicitud) REFERENCES solicitudes_recoleccion (id_solicitud)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- DATOS SEMILLA (SEED DATA)
-- -----------------------------------------------------------------
-- Inserciones iniciales necesarias para probar el sistema.
-- =================================================================

-- 1) Roles base del sistema ECOLAP
INSERT INTO roles (nombre_rol, descripcion) VALUES
    ('USUARIO',       'Ciudadano registrado que recicla y acumula puntos ECOLAP'),
    ('RECOLECTOR',    'Conductor/operador asignado a rutas de recolección'),
    ('ADMINISTRADOR', 'Administrador del sistema con acceso al panel de control');

-- 2) Usuario administrador de prueba
-- La contraseña es "Admin123" cifrada (hash bcrypt de ejemplo)
INSERT INTO usuarios (nombre, email, password_hash, telefono, id_rol, puntos_acumulados, estado) VALUES
    ('Administrador ECOLAP', 'admin@ecolap.com', '$2y$10$abcdefghijklmnopqrstuv1234567890ABCDEFGHIJKLMNOPQRSTUVWX', '+57 300 000 0000', 3, 0, 'activo');

-- 3) Dos puntos de reciclaje iniciales (coordenadas de ejemplo)
INSERT INTO puntos_reciclaje (nombre, direccion, latitud, longitud, tipo_material, id_administrador) VALUES
    ('Punto Verde Centro',      'Plaza Principal, Cra 7 con Calle 24',  4.71100000, -74.07210000, 'General',    1),
    ('Punto Ecológico Norte',   'Parque Norte, Calle 100 #15-20',      4.75330000, -74.04450000, 'Plástico',   1);

-- 4) Dos artículos educativos iniciales para la sección Aprende
INSERT INTO contenido_educativo (titulo, categoria, descripcion, url_media, id_administrador) VALUES
    ('Guía ECOLAP de Separación de Residuos',
     'Guías',
     'Aprende paso a paso el método oficial ECOLAP para clasificar residuos en orgánicos, reciclables y peligrosos.',
     'https://ecolap.com/media/guia-separacion.jpg',
     1),
    ('Manual de Compostaje Urbano',
     'Tutoriales',
     'Convierte tus residuos orgánicos en abono natural con técnicas profesionales de compostaje doméstico.',
     'https://ecolap.com/media/compostaje.jpg',
     1);

-- =================================================================
-- CONSULTAS DE VERIFICACIÓN (opcional, para comprobar la creación)
-- =================================================================
SELECT 'Base de datos ecolap_db creada correctamente' AS estado;
SELECT COUNT(*) AS total_roles FROM roles;
SELECT COUNT(*) AS total_usuarios FROM usuarios;
SELECT COUNT(*) AS total_puntos FROM puntos_reciclaje;
SELECT COUNT(*) AS total_contenido FROM contenido_educativo;