const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Servir archivos estáticos (HTML, CSS, JS, APK)
app.use(express.static('./'));

// Configuración de la conexión a MySQL Workbench
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',      // Tu usuario de MySQL
    password: '',      // Coloca tu contraseña de MySQL de Workbench aquí (si tienes)
    database: 'ecolap_db'
});

db.connect((err) => {
    if (err) {
        console.error('❌ Error conectando a MySQL:', err);
    } else {
        console.log('✅ Conectado exitosamente a la base de datos ecolap_db');
    }
});

// ==========================================
// ENDPOINTS / RUTAS DE LA API
// ==========================================

// 1. Obtener Puntos de Reciclaje (Para mapa.html)
app.get('/api/puntos', (req, res) => {
    db.query('SELECT * FROM puntos_reciclaje', (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// 2. Iniciar Sesión (Para login.html)
app.post('/api/login', (req, res) => {
    const { email, password } = req.body;
    const query = 'SELECT u.*, r.nombre_rol FROM usuarios u JOIN roles r ON u.id_rol = r.id_rol WHERE u.email = ?';
    
    db.query(query, [email], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length === 0) return res.status(401).json({ mensaje: 'Usuario no encontrado' });

        const usuario = results[0];
        // Nota: En producción usaremos bcrypt, por ahora valida texto plano si es de prueba
        if (usuario.password_hash === password) {
            res.json({
                mensaje: 'Login exitoso',
                usuario: {
                    id: usuario.id_usuario,
                    nombre: usuario.nombre,
                    email: usuario.email,
                    rol: usuario.nombre_rol,
                    puntos: usuario.puntos_acumulados
                }
            });
        } else {
            res.status(401).json({ mensaje: 'Contraseña incorrecta' });
        }
    });
});

// 3. Registrar Nuevo Usuario (Para registerForm en login.html)
app.post('/api/register', (req, res) => {
    const { nombre, email, password, rol } = req.body;

    // Convertimos el rol recibido ('usuario', 'conductor', 'admin') al ID de tu tabla roles
    let id_rol = 1; // Por defecto USUARIO
    if (rol === 'conductor') id_rol = 2; // RECOLECTOR
    if (rol === 'admin') id_rol = 3;     // ADMINISTRADOR

    // Verificar si el correo ya existe
    const checkQuery = 'SELECT * FROM usuarios WHERE email = ?';
    db.query(checkQuery, [email], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length > 0) {
            return res.status(400).json({ mensaje: 'El correo electrónico ya está registrado.' });
        }

        // Insertar el nuevo usuario en MySQL
        const insertQuery = 'INSERT INTO usuarios (nombre, email, password_hash, id_rol, puntos_acumulados, fecha_registro, estado) VALUES (?, ?, ?, ?, 0, NOW(), "activo")';
        db.query(insertQuery, [nombre, email, password, id_rol], (err, result) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ mensaje: 'Usuario registrado exitosamente', id_usuario: result.insertId });
        });
    });
});

// 4. Iniciar Sesión / Registro con Google (Para login.html)
app.post('/api/google-login', (req, res) => {
    const { nombre, email, google_id } = req.body;

    // Buscar si el usuario ya existe en la BD
    const checkQuery = 'SELECT u.*, r.nombre_rol FROM usuarios u JOIN roles r ON u.id_rol = r.id_rol WHERE u.email = ?';
    
    db.query(checkQuery, [email], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });

        if (results.length > 0) {
            // Si el usuario existe, inicia sesión directamente
            const usuario = results[0];
            return res.json({
                mensaje: 'Login con Google exitoso',
                usuario: {
                    id: usuario.id_usuario,
                    nombre: usuario.nombre,
                    email: usuario.email,
                    rol: usuario.nombre_rol,
                    puntos: usuario.puntos_acumulados
                }
            });
        } else {
            // Si no existe, lo registra automáticamente como USUARIO (id_rol = 1)
            const insertQuery = 'INSERT INTO usuarios (nombre, email, password_hash, id_rol, puntos_acumulados, fecha_registro, estado) VALUES (?, ?, ?, 1, 0, NOW(), "activo")';
            
            db.query(insertQuery, [nombre, email, google_id || 'GOOGLE_AUTH'], (err, result) => {
                if (err) return res.status(500).json({ error: err.message });

                res.json({
                    mensaje: 'Cuenta creada con Google exitosamente',
                    usuario: {
                        id: result.insertId,
                        nombre: nombre,
                        email: email,
                        rol: 'USUARIO',
                        puntos: 0
                    }
                });
            });
        }
    });
});

// 5. Crear Solicitud de Recolección
app.post('/api/solicitudes', (req, res) => {
    const { id_usuario, direccion, latitud, longitud, tipo_residuo } = req.body;
    const query = 'INSERT INTO solicitudes_recoleccion (id_usuario, direccion, latitud, longitud, tipo_residuo, estado_solicitud, fecha_solicitud) VALUES (?, ?, ?, ?, ?, "Pendiente", NOW())';

    db.query(query, [id_usuario, direccion, latitud, longitud, tipo_residuo], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ mensaje: 'Solicitud creada con éxito', id_solicitud: result.insertId });
    });
});

// Iniciar servidor local
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor ECOLAP corriendo en http://localhost:${PORT}`);
});