-- ═══════════════════════════════════════════════════════════════════
-- PROYECTO: DataDrive — Base de Datos Automotriz
-- VERSIÓN FINAL CORREGIDA Y MEJORADA
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- PASO 0: Eliminar todo usando un cursor dinámico
-- ─────────────────────────────────────────────────────────────────
DECLARE @sql NVARCHAR(MAX) = '';

-- Generar DROP para todas las FK de las tablas del proyecto
SELECT @sql += 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))
             + '.' + QUOTENAME(OBJECT_NAME(parent_object_id))
             + ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.foreign_keys
WHERE OBJECT_NAME(referenced_object_id) IN
      ('Productos','Clientes','Bundles','Ventas','Detalle_Bundle','Detalle_Venta','Facturas','Inventario');

IF LEN(@sql) > 0 EXEC sp_executesql @sql;
GO

-- Ahora sí eliminar vistas y tablas sin restricciones
IF OBJECT_ID('dbo.vw_Alertas_Inventario',    'V') IS NOT NULL DROP VIEW dbo.vw_Alertas_Inventario;
IF OBJECT_ID('dbo.vw_Perfil_Cliente',        'V') IS NOT NULL DROP VIEW dbo.vw_Perfil_Cliente;
IF OBJECT_ID('dbo.vw_Coaparicion_Productos', 'V') IS NOT NULL DROP VIEW dbo.vw_Coaparicion_Productos;
IF OBJECT_ID('dbo.vw_Performance_Bundles',   'V') IS NOT NULL DROP VIEW dbo.vw_Performance_Bundles;

IF OBJECT_ID('dbo.Inventario',     'U') IS NOT NULL DROP TABLE dbo.Inventario;
IF OBJECT_ID('dbo.Facturas',       'U') IS NOT NULL DROP TABLE dbo.Facturas;
IF OBJECT_ID('dbo.Detalle_Venta',  'U') IS NOT NULL DROP TABLE dbo.Detalle_Venta;
IF OBJECT_ID('dbo.Detalle_Bundle', 'U') IS NOT NULL DROP TABLE dbo.Detalle_Bundle;
IF OBJECT_ID('dbo.Ventas',         'U') IS NOT NULL DROP TABLE dbo.Ventas;
IF OBJECT_ID('dbo.Bundles',        'U') IS NOT NULL DROP TABLE dbo.Bundles;
IF OBJECT_ID('dbo.Clientes',       'U') IS NOT NULL DROP TABLE dbo.Clientes;
IF OBJECT_ID('dbo.Productos',      'U') IS NOT NULL DROP TABLE dbo.Productos;
GO

-- TABLA 1: Productos
CREATE TABLE Productos (
    id_producto     INT IDENTITY(1,1) PRIMARY KEY,
    codigo          VARCHAR(10)   NOT NULL UNIQUE,
    nombre          VARCHAR(120)  NOT NULL,
    categoria       VARCHAR(50),
    tipo_vehiculo   VARCHAR(10),       -- 'carro' o 'moto'
    precio_costo    INT,               -- cuanto nos costo
    precio_venta    INT,               -- cuanto lo vendemos
    marca           VARCHAR(60),
    activo          BIT DEFAULT 1      -- 1=activo, 0=inactivo
);
GO

-- TABLA 2: Clientes
-- Datos de las personas que compran en la tienda
CREATE TABLE Clientes (
    id_cliente      INT IDENTITY(1,1) PRIMARY KEY,
    nombres         VARCHAR(80)   NOT NULL,
    apellidos       VARCHAR(80)   NOT NULL,
    email           VARCHAR(120),
    telefono        VARCHAR(20),
    ciudad          VARCHAR(60),
    tipo_vehiculo   VARCHAR(10),       -- 'carro', 'moto' o 'ambos'
    fecha_registro  DATE
);
GO

-- TABLA 3: Bundles (Kits / Combos)
-- Los paquetes generados automaticamente por el Motor LM
-- lift     = que tan fuerte es la asociacion entre productos
-- confianza= probabilidad de que se compren juntos
CREATE TABLE Bundles (
    id_bundle       VARCHAR(10)   PRIMARY KEY,
    nombre          VARCHAR(120)  NOT NULL,
    tipo_vehiculo   VARCHAR(10),
    descuento_pct   DECIMAL(5,2), -- % de descuento aplicado
    lift            DECIMAL(5,3), -- fuerza de asociacion (>1 es bueno)
    confianza       DECIMAL(5,3), -- probabilidad de co-compra
    activo          BIT DEFAULT 1
);
GO

-- TABLA 4: Detalle_Bundle
-- Indica que productos forman cada bundle/kit
CREATE TABLE Detalle_Bundle (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    id_bundle       VARCHAR(10)  REFERENCES Bundles(id_bundle),
    codigo_producto VARCHAR(10)  REFERENCES Productos(codigo)
);
GO

-- TABLA 5: Ventas
-- Una fila por cada compra realizada en la tienda
CREATE TABLE Ventas (
    id_venta        INT IDENTITY(1,1) PRIMARY KEY,
    id_cliente      INT           REFERENCES Clientes(id_cliente),
    fecha_venta     DATE          NOT NULL,
    canal           VARCHAR(20),       -- 'tienda', 'web', 'telefono'
    subtotal        INT,               -- precio antes del descuento
    descuento_pesos INT DEFAULT 0,     -- cuanto se ahorro el cliente
    total           INT,               -- precio final pagado
    id_bundle       VARCHAR(10)        -- NULL si no aplico ningun kit
);
GO

-- TABLA 6: Detalle_Venta
-- Productos que se compraron en cada venta
CREATE TABLE Detalle_Venta (
    id_detalle      INT IDENTITY(1,1) PRIMARY KEY,
    id_venta        INT           REFERENCES Ventas(id_venta),
    codigo_producto VARCHAR(10)   REFERENCES Productos(codigo),
    cantidad        INT DEFAULT 1,
    precio_unitario INT,
    subtotal_linea  INT
);
GO

-- TABLA 7: Facturas
-- Documento oficial de cada venta
CREATE TABLE Facturas (
    id_factura      INT IDENTITY(1,1) PRIMARY KEY,
    numero_factura  VARCHAR(20)   NOT NULL UNIQUE,
    id_venta        INT           REFERENCES Ventas(id_venta),
    fecha_emision   DATE,
    estado          VARCHAR(20),       -- 'pagada', 'pendiente', 'anulada'
    metodo_pago     VARCHAR(30),       -- 'efectivo', 'tarjeta', etc.
    total_factura   INT
);
GO

-- TABLA 8: Inventario
-- Cantidad de productos disponibles en bodega
CREATE TABLE Inventario (
    id_inventario       INT IDENTITY(1,1) PRIMARY KEY,
    codigo_producto     VARCHAR(10)  REFERENCES Productos(codigo),
    stock_actual        INT,          -- unidades disponibles ahora
    stock_minimo        INT,          -- alerta si baja de este numero
    stock_maximo        INT,          -- capacidad maxima de bodega
    ubicacion           VARCHAR(80),
    fecha_ultima_entrada DATE,        -- ultima vez que llego mercancia
    fecha_ultima_salida  DATE         -- ultima vez que salio mercancia
);
GO


-- ── Insertar Productos (28 registros) ──
SET IDENTITY_INSERT Productos OFF;  
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_TAP', 'Tapetes premium silicona', 'Proteccion', 'carro', 65000, 120000, 'AutoPro', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_SEN', 'Sensores de reversa 4pts', 'Seguridad', 'carro', 45000, 85000, 'SensoTech', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_FOR', 'Forros de asientos cuero eco', 'Confort', 'carro', 110000, 200000, 'ComfortDrive', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_CAM', 'Camara de reversa HD', 'Seguridad', 'carro', 80000, 150000, 'VisionCar', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_LUC', 'Luces LED interiores RGB', 'Iluminacion', 'carro', 22000, 45000, 'LedAuto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_CAR', 'Cargador USB doble 3.1A', 'Electronica', 'carro', 18000, 35000, 'PowerDrive', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_ALA', 'Sistema de alarma con GPS', 'Seguridad', 'carro', 130000, 250000, 'SecureCar', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_PAR', 'Parasol delantero XL', 'Proteccion', 'carro', 15000, 30000, 'SolarShield', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_ARO', 'Aromatizante premium 3pack', 'Confort', 'carro', 12000, 25000, 'FreshCar', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_LIM', 'Limpiaparabrisas premium', 'Proteccion', 'carro', 28000, 55000, 'ClearView', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_CUS', 'Cojines lumbar ergonomicos', 'Confort', 'carro', 38000, 70000, 'SpineCare', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_HUD', 'Pantalla HUD velocidad', 'Electronica', 'carro', 95000, 180000, 'DigiDrive', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_NEU', 'Inflador portatil 12V', 'Herramientas', 'carro', 35000, 65000, 'AirPro', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('C_EXT', 'Extintor cabina 1kg', 'Seguridad', 'carro', 20000, 40000, 'SafeCar', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_CAS', 'Casco modular premium', 'Seguridad', 'moto', 240000, 450000, 'MotoShield', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_GUA', 'Guantes cuero touring', 'Proteccion', 'moto', 52000, 95000, 'GripPro', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_CHA', 'Chaleco reflectivo alta vis', 'Seguridad', 'moto', 40000, 75000, 'SafeRider', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_INT', 'Intercomunicador Bluetooth', 'Electronica', 'moto', 150000, 280000, 'TalkMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_BAU', 'Baul trasero rigido 45L', 'Carga', 'moto', 120000, 220000, 'CargoMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_CAR', 'Cargador USB moto imperm.', 'Electronica', 'moto', 24000, 45000, 'PowerMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_GPS', 'Soporte GPS celular moto', 'Navegacion', 'moto', 32000, 60000, 'NaviMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_CUB', 'Cubierta impermeable moto', 'Proteccion', 'moto', 28000, 55000, 'RainShield', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_MAN', 'Manoplas calefactoras', 'Confort', 'moto', 70000, 130000, 'WarmRide', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_ALF', 'Alfombra taller antidesliz', 'Herramientas', 'moto', 18000, 35000, 'WorkMat', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_EXT', 'Extintor moto 500g', 'Seguridad', 'moto', 19000, 38000, 'SafeMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_CEL', 'Alarma GPS antirrobo', 'Seguridad', 'moto', 105000, 195000, 'TrackMoto', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_ROD', 'Rodilleras articuladas', 'Proteccion', 'moto', 46000, 85000, 'KneeGuard', 1);
INSERT INTO Productos (codigo, nombre, categoria, tipo_vehiculo, precio_costo, precio_venta, marca, activo) VALUES ('M_BOT', 'Botas moto touring impermeables', 'Proteccion', 'moto', 205000, 380000, 'BootPro', 1);
GO

-- ── Insertar Clientes  ──
SET IDENTITY_INSERT Clientes OFF;  
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Carlos', 'Vargas Hernandez', 'carlos.vargas32@gmail.com', '3129958838', 'Cali', 'moto', '2023-11-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Perez Garcia', 'alejandro.perez4@gmail.com', '3112575562', 'Barranquilla', 'carro', '2023-09-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Lopez Vargas', 'diego.lopez84@gmail.com', '3194130244', 'Manizales', 'carro', '2023-08-27');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Moreno Moreno', 'maria.moreno21@gmail.com', '3193702683', 'Manizales', 'carro', '2022-06-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Martinez Martinez', 'david.martinez49@gmail.com', '3112981052', 'Pereira', 'moto', '2023-09-11');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Vargas Sanchez', 'maria.vargas69@gmail.com', '3116753883', 'Manizales', 'carro', '2022-10-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Lopez Vargas', 'juliana.lopez9@gmail.com', '3106150444', 'Barranquilla', 'moto', '2022-03-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Perez Hernandez', 'juan.perez59@gmail.com', '3185320121', 'Pereira', 'carro', '2022-12-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Vargas Romero', 'luis.vargas88@gmail.com', '3186977837', 'Medellin', 'moto', '2022-06-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Sanchez Perez', 'andres.sanchez35@gmail.com', '3185899313', 'Barranquilla', 'moto', '2024-05-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Jimenez Garcia', 'miguel.jimenez41@gmail.com', '3153843426', 'Bucaramanga', 'carro', '2023-08-04');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Castro Sanchez', 'valentina.castro51@gmail.com', '3186282117', 'Cartagena', 'carro', '2022-05-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Torres Hernandez', 'diego.torres96@gmail.com', '3178461803', 'Manizales', 'moto', '2023-02-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Rodriguez Torres', 'valentina.rodriguez64@gmail.com', '3112201654', 'Bogota', 'moto', '2022-06-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Ramirez Martinez', 'jorge.ramirez50@gmail.com', '3151220073', 'Cartagena', 'carro', '2023-07-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Castro Romero', 'juan.castro69@gmail.com', '3135812670', 'Pereira', 'carro', '2023-03-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Garcia Vargas', 'sebastian.garcia93@gmail.com', '3135351479', 'Cali', 'carro', '2022-04-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Ramirez Lopez', 'sofia.ramirez20@gmail.com', '3150185867', 'Cali', 'carro', '2024-03-08');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Gomez Sanchez', 'alejandro.gomez3@gmail.com', '3115014631', 'Pereira', 'moto', '2024-05-01');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Garcia Lopez', 'valentina.garcia73@gmail.com', '3110570592', 'Medellin', 'moto', '2024-04-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Moreno Rodriguez', 'diego.moreno17@gmail.com', '3188550256', 'Cartagena', 'ambos', '2022-06-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Jimenez Ramirez', 'sofia.jimenez55@gmail.com', '3128427073', 'Barranquilla', 'moto', '2023-02-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Romero Torres', 'camila.romero58@gmail.com', '3116240908', 'Barranquilla', 'carro', '2022-12-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Torres Lopez', 'alejandro.torres76@gmail.com', '3129557077', 'Bogota', 'carro', '2023-10-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Martinez Romero', 'miguel.martinez5@gmail.com', '3144349361', 'Medellin', 'carro', '2022-10-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Torres Rodriguez', 'valentina.torres93@gmail.com', '3176644106', 'Cartagena', 'carro', '2023-04-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Martinez Martinez', 'valentina.martinez85@gmail.com', '3157854710', 'Pereira', 'carro', '2023-04-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Garcia Perez', 'juan.garcia94@gmail.com', '3145540424', 'Medellin', 'carro', '2022-07-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Perez Rodriguez', 'laura.perez36@gmail.com', '3162092888', 'Barranquilla', 'moto', '2022-03-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Martinez Garcia', 'sofia.martinez84@gmail.com', '3172556484', 'Bogota', 'ambos', '2024-02-11');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Perez Sanchez', 'andres.perez62@gmail.com', '3128688676', 'Manizales', 'ambos', '2022-06-18');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Perez Hernandez', 'maria.perez59@gmail.com', '3138285503', 'Manizales', 'moto', '2024-01-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Lopez Hernandez', 'laura.lopez28@gmail.com', '3107849494', 'Bogota', 'moto', '2022-02-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Sanchez Torres', 'alejandro.sanchez68@gmail.com', '3121130263', 'Bogota', 'ambos', '2022-03-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Ramirez Martinez', 'juan.ramirez87@gmail.com', '3131568532', 'Manizales', 'carro', '2024-06-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Ramirez Garcia', 'alejandro.ramirez80@gmail.com', '3111003626', 'Manizales', 'moto', '2023-08-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Lopez Castro', 'isabella.lopez92@gmail.com', '3142169044', 'Barranquilla', 'carro', '2022-05-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Gomez Romero', 'camila.gomez97@gmail.com', '3109736572', 'Bogota', 'carro', '2023-07-31');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Torres Lopez', 'juan.torres65@gmail.com', '3135594597', 'Cali', 'ambos', '2024-06-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Gomez Hernandez', 'miguel.gomez21@gmail.com', '3158812137', 'Bucaramanga', 'moto', '2024-04-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Hernandez Romero', 'diego.hernandez85@gmail.com', '3113903144', 'Cali', 'carro', '2024-06-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Rodriguez Hernandez', 'diego.rodriguez37@gmail.com', '3181178885', 'Barranquilla', 'moto', '2022-07-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Sanchez Hernandez', 'sofia.sanchez7@gmail.com', '3112388090', 'Manizales', 'moto', '2022-02-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Moreno Rodriguez', 'david.moreno82@gmail.com', '3135159040', 'Cali', 'moto', '2023-07-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Garcia Martinez', 'sofia.garcia10@gmail.com', '3192747083', 'Cali', 'carro', '2024-05-04');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Torres Rodriguez', 'juliana.torres56@gmail.com', '3117105448', 'Bogota', 'carro', '2024-03-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Lopez Castro', 'david.lopez32@gmail.com', '3189514287', 'Medellin', 'carro', '2023-07-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Vargas Rodriguez', 'juliana.vargas31@gmail.com', '3121810617', 'Cali', 'moto', '2022-01-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Moreno Romero', 'david.moreno53@gmail.com', '3189913412', 'Barranquilla', 'carro', '2024-03-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Jimenez Garcia', 'jorge.jimenez61@gmail.com', '3129854548', 'Barranquilla', 'moto', '2023-04-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Jimenez Moreno', 'isabella.jimenez30@gmail.com', '3129920292', 'Bogota', 'moto', '2023-02-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Jimenez Martinez', 'isabella.jimenez99@gmail.com', '3137463522', 'Pereira', 'moto', '2023-02-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Martinez Romero', 'maria.martinez34@gmail.com', '3123966966', 'Bucaramanga', 'carro', '2023-09-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Vargas Moreno', 'natalia.vargas41@gmail.com', '3158571795', 'Medellin', 'carro', '2023-08-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Garcia Vargas', 'luis.garcia56@gmail.com', '3100226999', 'Barranquilla', 'carro', '2022-03-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Gomez Castro', 'juliana.gomez16@gmail.com', '3196603781', 'Bucaramanga', 'carro', '2023-11-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Perez Vargas', 'natalia.perez38@gmail.com', '3174411983', 'Cali', 'carro', '2023-11-12');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Ramirez Ramirez', 'laura.ramirez39@gmail.com', '3154502486', 'Bogota', 'carro', '2022-08-04');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Ramirez Castro', 'juliana.ramirez42@gmail.com', '3162409658', 'Cartagena', 'carro', '2022-08-07');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Castro Martinez', 'laura.castro37@gmail.com', '3169182797', 'Pereira', 'carro', '2024-02-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Lopez Moreno', 'luis.lopez26@gmail.com', '3119777514', 'Bogota', 'carro', '2023-05-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Perez Romero', 'sebastian.perez81@gmail.com', '3177265240', 'Barranquilla', 'moto', '2023-01-29');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Lopez Rodriguez', 'daniela.lopez84@gmail.com', '3192291118', 'Bogota', 'moto', '2024-05-31');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Lopez Rodriguez', 'jorge.lopez90@gmail.com', '3169519112', 'Cartagena', 'carro', '2022-09-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Rodriguez Moreno', 'sebastian.rodriguez60@gmail.com', '3189600766', 'Pereira', 'ambos', '2023-03-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Sanchez Romero', 'sofia.sanchez21@gmail.com', '3199811743', 'Cartagena', 'carro', '2024-02-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Moreno Moreno', 'luis.moreno67@gmail.com', '3165041510', 'Barranquilla', 'carro', '2022-03-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Hernandez Gomez', 'valentina.hernandez41@gmail.com', '3172498004', 'Medellin', 'carro', '2022-08-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Vargas Lopez', 'laura.vargas9@gmail.com', '3155682626', 'Manizales', 'carro', '2023-04-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Lopez Jimenez', 'maria.lopez54@gmail.com', '3152274692', 'Bogota', 'moto', '2024-02-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Garcia Gomez', 'camila.garcia39@gmail.com', '3152343121', 'Manizales', 'carro', '2024-01-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Lopez Hernandez', 'sebastian.lopez56@gmail.com', '3165181765', 'Bogota', 'carro', '2023-11-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Jimenez Sanchez', 'laura.jimenez17@gmail.com', '3183517915', 'Bogota', 'ambos', '2023-08-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Castro Perez', 'juan.castro18@gmail.com', '3161968116', 'Cali', 'carro', '2023-01-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Sanchez Gomez', 'valentina.sanchez44@gmail.com', '3150885459', 'Bucaramanga', 'moto', '2024-05-01');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Jimenez Martinez', 'isabella.jimenez61@gmail.com', '3102601580', 'Bogota', 'ambos', '2022-12-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Moreno Castro', 'juan.moreno6@gmail.com', '3104164775', 'Barranquilla', 'carro', '2022-01-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Rodriguez Sanchez', 'miguel.rodriguez86@gmail.com', '3115353091', 'Barranquilla', 'carro', '2022-09-20');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Ramirez Ramirez', 'laura.ramirez96@gmail.com', '3196416275', 'Medellin', 'moto', '2022-06-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Ramirez Garcia', 'ana.ramirez40@gmail.com', '3177282128', 'Manizales', 'carro', '2024-01-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Ramirez Vargas', 'juan.ramirez81@gmail.com', '3132594692', 'Medellin', 'moto', '2022-11-05');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Moreno Garcia', 'alejandro.moreno45@gmail.com', '3171503856', 'Manizales', 'moto', '2022-03-12');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Jimenez Perez', 'maria.jimenez63@gmail.com', '3114165187', 'Manizales', 'ambos', '2023-10-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Perez Rodriguez', 'laura.perez94@gmail.com', '3170027662', 'Bucaramanga', 'moto', '2023-07-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Perez Jimenez', 'camila.perez94@gmail.com', '3179520597', 'Bucaramanga', 'carro', '2022-09-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Romero Sanchez', 'luis.romero32@gmail.com', '3162372114', 'Manizales', 'carro', '2023-05-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Sanchez Lopez', 'laura.sanchez46@gmail.com', '3134675473', 'Pereira', 'carro', '2023-09-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Garcia Torres', 'sofia.garcia25@gmail.com', '3111490777', 'Barranquilla', 'moto', '2023-05-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Castro Vargas', 'sebastian.castro63@gmail.com', '3160152969', 'Bogota', 'carro', '2022-08-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Hernandez Castro', 'valentina.hernandez75@gmail.com', '3149529086', 'Cartagena', 'moto', '2022-12-19');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Gomez Gomez', 'sofia.gomez90@gmail.com', '3160900658', 'Bucaramanga', 'carro', '2022-08-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Gomez Martinez', 'miguel.gomez96@gmail.com', '3171922443', 'Cali', 'carro', '2024-01-27');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Vargas Ramirez', 'isabella.vargas98@gmail.com', '3170415568', 'Bucaramanga', 'ambos', '2024-05-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Lopez Gomez', 'luis.lopez23@gmail.com', '3140569669', 'Bogota', 'moto', '2022-05-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Garcia Torres', 'maria.garcia38@gmail.com', '3193605777', 'Cali', 'moto', '2024-02-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Jimenez Garcia', 'ana.jimenez74@gmail.com', '3138163378', 'Cartagena', 'carro', '2022-12-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Carlos', 'Hernandez Jimenez', 'carlos.hernandez62@gmail.com', '3115312516', 'Medellin', 'carro', '2022-03-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Rodriguez Moreno', 'andres.rodriguez73@gmail.com', '3140780112', 'Medellin', 'ambos', '2022-05-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Ramirez Moreno', 'juliana.ramirez80@gmail.com', '3130291214', 'Manizales', 'carro', '2023-03-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Perez Hernandez', 'juliana.perez73@gmail.com', '3183352876', 'Bogota', 'moto', '2024-01-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Castro Lopez', 'miguel.castro34@gmail.com', '3188641164', 'Medellin', 'carro', '2022-06-27');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Garcia Perez', 'andres.garcia58@gmail.com', '3192525827', 'Cartagena', 'carro', '2022-08-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Vargas Jimenez', 'isabella.vargas59@gmail.com', '3109553585', 'Barranquilla', 'ambos', '2024-03-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Martinez Torres', 'jorge.martinez29@gmail.com', '3186924061', 'Cali', 'ambos', '2024-04-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Garcia Rodriguez', 'juan.garcia40@gmail.com', '3179865458', 'Bucaramanga', 'carro', '2023-04-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Hernandez Torres', 'daniela.hernandez70@gmail.com', '3166276072', 'Cartagena', 'carro', '2022-02-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Ramirez Hernandez', 'natalia.ramirez4@gmail.com', '3112257687', 'Barranquilla', 'ambos', '2024-05-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Ramirez Garcia', 'luis.ramirez98@gmail.com', '3123513701', 'Cartagena', 'carro', '2023-03-29');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Ramirez Perez', 'laura.ramirez82@gmail.com', '3165998319', 'Medellin', 'carro', '2023-02-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Castro Martinez', 'natalia.castro21@gmail.com', '3144265498', 'Manizales', 'moto', '2022-10-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Garcia Sanchez', 'sofia.garcia12@gmail.com', '3142213778', 'Bucaramanga', 'carro', '2024-03-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Jimenez Garcia', 'sofia.jimenez85@gmail.com', '3172825679', 'Cartagena', 'carro', '2022-07-12');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Moreno Sanchez', 'juliana.moreno81@gmail.com', '3159329732', 'Bogota', 'carro', '2023-07-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Sanchez Romero', 'luis.sanchez90@gmail.com', '3165056916', 'Medellin', 'carro', '2023-10-08');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Hernandez Torres', 'andres.hernandez2@gmail.com', '3174121929', 'Manizales', 'carro', '2024-05-11');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Martinez Castro', 'sebastian.martinez20@gmail.com', '3166890827', 'Bucaramanga', 'carro', '2022-10-07');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Sanchez Lopez', 'camila.sanchez59@gmail.com', '3173989546', 'Cali', 'carro', '2023-09-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Hernandez Moreno', 'juan.hernandez54@gmail.com', '3145617282', 'Bucaramanga', 'moto', '2022-10-17');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Ramirez Castro', 'juliana.ramirez63@gmail.com', '3119944139', 'Cartagena', 'carro', '2022-12-20');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Moreno Torres', 'sofia.moreno49@gmail.com', '3161115319', 'Pereira', 'moto', '2023-12-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Perez Lopez', 'alejandro.perez53@gmail.com', '3105858241', 'Pereira', 'moto', '2023-12-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Castro Moreno', 'daniela.castro84@gmail.com', '3120415230', 'Cartagena', 'ambos', '2022-05-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Jimenez Jimenez', 'ana.jimenez57@gmail.com', '3113383077', 'Cartagena', 'carro', '2022-05-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Martinez Sanchez', 'laura.martinez34@gmail.com', '3145440919', 'Manizales', 'moto', '2024-05-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Perez Gomez', 'sofia.perez81@gmail.com', '3196464619', 'Cartagena', 'moto', '2022-02-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Castro Castro', 'miguel.castro37@gmail.com', '3130532691', 'Medellin', 'carro', '2022-04-11');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Rodriguez Vargas', 'sebastian.rodriguez39@gmail.com', '3103885234', 'Bogota', 'carro', '2022-02-27');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Gomez Perez', 'natalia.gomez19@gmail.com', '3132775624', 'Manizales', 'moto', '2024-03-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Rodriguez Martinez', 'andres.rodriguez79@gmail.com', '3151344226', 'Barranquilla', 'carro', '2023-08-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Sanchez Castro', 'miguel.sanchez33@gmail.com', '3161682508', 'Bucaramanga', 'moto', '2024-04-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Castro Torres', 'isabella.castro21@gmail.com', '3109913576', 'Cartagena', 'ambos', '2023-08-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Vargas Hernandez', 'daniela.vargas59@gmail.com', '3140550084', 'Barranquilla', 'ambos', '2024-05-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Lopez Perez', 'ana.lopez74@gmail.com', '3148178682', 'Bucaramanga', 'ambos', '2022-10-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Hernandez Garcia', 'jorge.hernandez73@gmail.com', '3192046449', 'Bogota', 'ambos', '2024-02-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Moreno Moreno', 'isabella.moreno30@gmail.com', '3181478884', 'Pereira', 'carro', '2022-07-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Castro Martinez', 'laura.castro81@gmail.com', '3186750368', 'Bogota', 'carro', '2023-03-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Gomez Vargas', 'alejandro.gomez17@gmail.com', '3112097496', 'Bucaramanga', 'carro', '2023-03-02');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Rodriguez Moreno', 'miguel.rodriguez70@gmail.com', '3149104566', 'Bucaramanga', 'moto', '2022-09-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Vargas Jimenez', 'isabella.vargas44@gmail.com', '3115457816', 'Cartagena', 'ambos', '2022-05-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Jimenez Moreno', 'jorge.jimenez72@gmail.com', '3149093496', 'Medellin', 'moto', '2022-01-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Martinez Sanchez', 'sofia.martinez48@gmail.com', '3190305496', 'Bucaramanga', 'moto', '2024-04-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Castro Lopez', 'ana.castro61@gmail.com', '3103358751', 'Pereira', 'ambos', '2022-08-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sebastian', 'Romero Vargas', 'sebastian.romero39@gmail.com', '3187139443', 'Manizales', 'carro', '2022-02-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Sanchez Martinez', 'luis.sanchez13@gmail.com', '3131514326', 'Cali', 'carro', '2023-01-15');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Vargas Vargas', 'juliana.vargas20@gmail.com', '3155684858', 'Medellin', 'moto', '2023-09-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Garcia Vargas', 'isabella.garcia48@gmail.com', '3129161443', 'Cartagena', 'carro', '2022-08-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Castro Gomez', 'ana.castro70@gmail.com', '3186547189', 'Pereira', 'carro', '2022-10-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juan', 'Jimenez Jimenez', 'juan.jimenez59@gmail.com', '3112304198', 'Barranquilla', 'moto', '2023-09-04');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Carlos', 'Moreno Gomez', 'carlos.moreno32@gmail.com', '3116901217', 'Barranquilla', 'carro', '2024-02-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Lopez Jimenez', 'alejandro.lopez30@gmail.com', '3144098516', 'Cali', 'moto', '2023-09-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Jimenez Rodriguez', 'luis.jimenez17@gmail.com', '3172506491', 'Bucaramanga', 'moto', '2022-04-23');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Garcia Gomez', 'andres.garcia31@gmail.com', '3179034501', 'Pereira', 'carro', '2022-09-29');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Vargas Perez', 'andres.vargas68@gmail.com', '3115253751', 'Medellin', 'carro', '2024-03-07');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Ramirez Martinez', 'sofia.ramirez58@gmail.com', '3167624084', 'Barranquilla', 'ambos', '2022-02-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Castro Garcia', 'camila.castro8@gmail.com', '3164287863', 'Manizales', 'carro', '2022-04-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Martinez Romero', 'camila.martinez11@gmail.com', '3143233116', 'Cali', 'carro', '2022-10-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Ramirez Torres', 'daniela.ramirez38@gmail.com', '3160896652', 'Manizales', 'carro', '2023-12-20');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Vargas Jimenez', 'diego.vargas28@gmail.com', '3157723010', 'Cartagena', 'moto', '2023-02-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Perez Perez', 'camila.perez94@gmail.com', '3112762205', 'Pereira', 'carro', '2023-11-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Rodriguez Castro', 'natalia.rodriguez61@gmail.com', '3109010480', 'Medellin', 'moto', '2022-04-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Vargas Vargas', 'ana.vargas48@gmail.com', '3117463800', 'Bogota', 'moto', '2023-07-30');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Perez Gomez', 'ana.perez86@gmail.com', '3156765623', 'Bogota', 'ambos', '2023-09-07');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Martinez Ramirez', 'natalia.martinez65@gmail.com', '3128553319', 'Cali', 'moto', '2022-08-18');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Jimenez Torres', 'david.jimenez48@gmail.com', '3115419645', 'Bucaramanga', 'moto', '2024-04-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Sofia', 'Moreno Jimenez', 'sofia.moreno80@gmail.com', '3182352411', 'Bogota', 'moto', '2023-11-05');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Maria', 'Rodriguez Hernandez', 'maria.rodriguez90@gmail.com', '3141471222', 'Pereira', 'carro', '2022-07-05');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Castro Perez', 'alejandro.castro9@gmail.com', '3119042093', 'Bogota', 'carro', '2023-06-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Perez Sanchez', 'jorge.perez44@gmail.com', '3121127115', 'Pereira', 'carro', '2022-11-29');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Carlos', 'Rodriguez Rodriguez', 'carlos.rodriguez97@gmail.com', '3182924837', 'Bogota', 'moto', '2022-10-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Daniela', 'Sanchez Ramirez', 'daniela.sanchez57@gmail.com', '3155590800', 'Bucaramanga', 'carro', '2023-06-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Perez Martinez', 'david.perez37@gmail.com', '3191028864', 'Cartagena', 'carro', '2022-11-12');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Perez Ramirez', 'miguel.perez8@gmail.com', '3101031743', 'Barranquilla', 'carro', '2022-08-05');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Hernandez Gomez', 'luis.hernandez16@gmail.com', '3101037490', 'Cartagena', 'moto', '2022-06-29');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Torres Vargas', 'jorge.torres30@gmail.com', '3167144075', 'Pereira', 'carro', '2024-06-01');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Garcia Sanchez', 'jorge.garcia10@gmail.com', '3142018286', 'Manizales', 'moto', '2023-12-28');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Isabella', 'Martinez Perez', 'isabella.martinez3@gmail.com', '3143589647', 'Cali', 'moto', '2023-09-25');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Martinez Perez', 'natalia.martinez14@gmail.com', '3132657384', 'Manizales', 'moto', '2023-06-21');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Jorge', 'Jimenez Hernandez', 'jorge.jimenez96@gmail.com', '3145568701', 'Barranquilla', 'carro', '2022-06-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Castro Martinez', 'diego.castro68@gmail.com', '3168444607', 'Barranquilla', 'ambos', '2022-12-24');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Lopez Martinez', 'laura.lopez19@gmail.com', '3134355473', 'Barranquilla', 'carro', '2022-06-06');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Andres', 'Moreno Castro', 'andres.moreno64@gmail.com', '3162270726', 'Cartagena', 'moto', '2024-06-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Rodriguez Sanchez', 'natalia.rodriguez9@gmail.com', '3162937522', 'Cartagena', 'moto', '2024-03-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Juliana', 'Garcia Gomez', 'juliana.garcia65@gmail.com', '3109957701', 'Bucaramanga', 'carro', '2022-02-08');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Jimenez Hernandez', 'david.jimenez10@gmail.com', '3186525668', 'Medellin', 'moto', '2023-06-04');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Ramirez Torres', 'camila.ramirez95@gmail.com', '3105505975', 'Cartagena', 'ambos', '2023-08-09');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Ramirez Sanchez', 'david.ramirez65@gmail.com', '3120248230', 'Bogota', 'carro', '2024-04-10');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Ana', 'Torres Castro', 'ana.torres23@gmail.com', '3105253567', 'Barranquilla', 'moto', '2023-03-26');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Gomez Romero', 'david.gomez37@gmail.com', '3151998170', 'Manizales', 'moto', '2023-11-27');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Martinez Gomez', 'david.martinez13@gmail.com', '3174888554', 'Manizales', 'carro', '2024-01-12');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('David', 'Martinez Ramirez', 'david.martinez85@gmail.com', '3118982195', 'Pereira', 'carro', '2023-11-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Laura', 'Ramirez Vargas', 'laura.ramirez11@gmail.com', '3141551377', 'Manizales', 'moto', '2022-12-03');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Martinez Castro', 'diego.martinez86@gmail.com', '3156828640', 'Pereira', 'carro', '2022-11-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Miguel', 'Gomez Moreno', 'miguel.gomez63@gmail.com', '3125770506', 'Barranquilla', 'ambos', '2022-06-08');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Luis', 'Jimenez Moreno', 'luis.jimenez13@gmail.com', '3168140959', 'Bogota', 'moto', '2024-06-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Perez Rodriguez', 'alejandro.perez21@gmail.com', '3124272734', 'Cali', 'moto', '2022-02-14');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Natalia', 'Castro Vargas', 'natalia.castro31@gmail.com', '3159619341', 'Bucaramanga', 'moto', '2024-03-13');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Valentina', 'Torres Lopez', 'valentina.torres40@gmail.com', '3162950208', 'Barranquilla', 'carro', '2023-08-08');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Camila', 'Moreno Hernandez', 'camila.moreno49@gmail.com', '3167498993', 'Manizales', 'ambos', '2024-04-16');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Alejandro', 'Rodriguez Jimenez', 'alejandro.rodriguez33@gmail.com', '3107003454', 'Cartagena', 'moto', '2023-07-22');
INSERT INTO Clientes (nombres, apellidos, email, telefono, ciudad, tipo_vehiculo, fecha_registro) VALUES ('Diego', 'Jimenez Martinez', 'diego.jimenez37@gmail.com', '3111257528', 'Cali', 'carro', '2023-06-10');
GO

-- ── Insertar Bundles (12 registros) ──
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-001', 'Kit Vision Trasera', 'carro', 16.0, 4.54, 1.0, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-002', 'Kit Forros + Tapetes', 'carro', 11.2, 3.14, 0.69, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-003', 'Kit Confort Total Carro', 'carro', 15.9, 3.78, 0.83, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-004', 'Kit Cojines + Forros', 'carro', 16.0, 4.54, 1.0, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-005', 'Kit Seguridad Carro', 'carro', 14.5, 3.2, 0.75, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-006', 'Kit Emergencia Carro', 'carro', 8.0, 2.1, 0.8, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-007', 'Kit Piloto Basico', 'moto', 14.2, 4.02, 0.82, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-008', 'Kit Casco + Intercomunicador', 'moto', 12.2, 3.51, 0.71, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-009', 'Kit Touring Moto', 'moto', 13.5, 3.0, 0.75, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-010', 'Kit Seguridad Moto Full', 'moto', 18.0, 3.8, 0.7, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-011', 'Kit Proteccion Piernas', 'moto', 10.0, 2.8, 0.75, 1);
INSERT INTO Bundles (id_bundle, nombre, tipo_vehiculo, descuento_pct, lift, confianza, activo) VALUES ('KIT-012', 'Kit Tech Rider', 'moto', 12.0, 3.2, 0.78, 1);
GO

-- ── Insertar Detalle_Bundle (30 registros) ──
SET IDENTITY_INSERT Detalle_Bundle OFF; 
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-001', 'C_SEN');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-001', 'C_CAM');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-002', 'C_FOR');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-002', 'C_TAP');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-003', 'C_TAP');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-003', 'C_SEN');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-003', 'C_FOR');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-004', 'C_CUS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-004', 'C_FOR');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-005', 'C_SEN');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-005', 'C_CAM');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-005', 'C_ALA');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-006', 'C_NEU');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-006', 'C_EXT');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-007', 'M_CAS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-007', 'M_GUA');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-008', 'M_CAS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-008', 'M_INT');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-009', 'M_BAU');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-009', 'M_CAR');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-009', 'M_GPS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-010', 'M_CAS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-010', 'M_GUA');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-010', 'M_ROD');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-010', 'M_BOT');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-011', 'M_ROD');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-011', 'M_BOT');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-012', 'M_INT');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-012', 'M_GPS');
INSERT INTO Detalle_Bundle (id_bundle, codigo_producto) VALUES ('KIT-012', 'M_CAR');
GO

-- ── Insertar Ventas  ──
SET IDENTITY_INSERT Ventas OFF;
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (38, '2026-03-31', 'web', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (107, '2025-07-04', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (96, '2025-05-20', 'web', 355000, 56800, 298200, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (10, '2025-09-25', 'telefono', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (115, '2025-09-10', 'web', 310000, 0, 310000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (141, '2025-08-30', 'tienda', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (78, '2025-07-18', 'telefono', 570000, 63840, 506160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (29, '2025-06-29', 'telefono', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (184, '2026-04-19', 'web', 775000, 104625, 670375, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (48, '2026-02-11', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (100, '2025-06-21', 'web', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (192, '2026-03-06', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (198, '2025-12-10', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (140, '2025-05-24', 'telefono', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (162, '2025-05-23', 'telefono', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (76, '2025-06-24', 'web', 255000, 20400, 234600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (140, '2025-08-27', 'tienda', 360000, 0, 360000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (200, '2025-09-04', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (112, '2026-01-21', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (128, '2026-03-12', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (21, '2025-05-21', 'telefono', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (27, '2026-02-19', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (43, '2025-08-17', 'tienda', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2026-04-05', 'tienda', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (132, '2026-05-02', 'tienda', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (9, '2026-02-11', 'web', 410000, 55350, 354650, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (146, '2025-12-08', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (114, '2025-08-28', 'web', 615000, 98400, 516600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (167, '2025-12-23', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (133, '2026-03-05', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (55, '2025-09-27', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (116, '2025-05-11', 'tienda', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (182, '2025-07-28', 'web', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2026-04-30', 'tienda', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2025-12-10', 'telefono', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (17, '2025-10-29', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (148, '2025-09-27', 'tienda', 775000, 94550, 680450, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (175, '2025-07-26', 'telefono', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (197, '2025-08-26', 'tienda', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (78, '2025-10-27', 'web', 665000, 106400, 558600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (21, '2025-06-29', 'tienda', 240000, 0, 240000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (129, '2025-06-24', 'tienda', 610000, 97600, 512400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-11-18', 'tienda', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (167, '2025-06-26', 'telefono', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (161, '2025-11-07', 'tienda', 605000, 81675, 523325, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (117, '2025-10-31', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (119, '2026-03-13', 'web', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (103, '2025-09-20', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (62, '2025-05-30', 'tienda', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (75, '2025-12-29', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (148, '2026-02-06', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (128, '2025-07-10', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (62, '2025-11-17', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (153, '2025-06-17', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (28, '2026-02-14', 'web', 150000, 12000, 138000, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (103, '2025-10-05', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (19, '2026-03-25', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (33, '2026-03-20', 'telefono', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (51, '2025-11-09', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (36, '2026-02-27', 'telefono', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (156, '2025-08-14', 'telefono', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (101, '2026-05-03', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (182, '2025-06-12', 'web', 635000, 0, 635000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (107, '2025-05-31', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (68, '2026-04-11', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (150, '2025-09-01', 'web', 313000, 0, 313000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (9, '2025-10-03', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (81, '2025-06-17', 'web', 420000, 0, 420000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (189, '2025-09-04', 'tienda', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (170, '2025-06-28', 'tienda', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (140, '2025-11-18', 'telefono', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (50, '2025-09-27', 'web', 1230000, 174660, 1055340, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (177, '2025-12-26', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (74, '2026-03-29', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (198, '2025-11-10', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (114, '2025-07-30', 'tienda', 585000, 93600, 491400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (144, '2025-11-13', 'telefono', 380000, 60800, 319200, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (63, '2025-11-05', 'tienda', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (26, '2025-08-23', 'tienda', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (141, '2026-04-16', 'web', 1048000, 148816, 899184, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (83, '2025-09-21', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (137, '2026-05-02', 'tienda', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (10, '2026-04-22', 'tienda', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (3, '2026-04-04', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (165, '2025-06-13', 'telefono', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (50, '2026-03-15', 'telefono', 750000, 106500, 643500, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (4, '2026-03-29', 'telefono', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (157, '2025-08-03', 'web', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (23, '2026-02-05', 'tienda', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (64, '2025-09-10', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (150, '2025-07-30', 'telefono', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (16, '2025-12-30', 'web', 600000, 96000, 504000, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (177, '2025-11-18', 'web', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (57, '2025-09-23', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (107, '2026-03-31', 'telefono', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (175, '2026-04-25', 'telefono', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (20, '2026-02-17', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2025-08-28', 'web', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (184, '2026-04-23', 'web', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (34, '2025-10-21', 'tienda', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2025-06-05', 'web', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (191, '2025-09-02', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (139, '2025-05-24', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (105, '2025-10-16', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (98, '2025-11-29', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (168, '2025-09-22', 'telefono', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (187, '2025-06-10', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (137, '2025-08-24', 'web', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2026-02-22', 'tienda', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (62, '2025-10-16', 'web', 1045000, 148390, 896610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (63, '2025-08-24', 'telefono', 288000, 0, 288000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (36, '2026-04-08', 'telefono', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (148, '2026-01-18', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (170, '2025-11-26', 'tienda', 260000, 0, 260000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (161, '2026-04-02', 'tienda', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (135, '2025-12-28', 'tienda', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (48, '2025-07-20', 'tienda', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (119, '2025-09-20', 'telefono', 400000, 0, 400000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (100, '2025-07-18', 'tienda', 1055000, 149810, 905190, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (24, '2025-09-11', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2026-02-19', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (123, '2026-02-07', 'web', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (49, '2025-09-19', 'tienda', 360000, 57600, 302400, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (102, '2026-03-03', 'web', 185000, 0, 185000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (79, '2025-12-13', 'web', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (195, '2026-03-02', 'web', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (12, '2025-11-28', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (76, '2025-11-09', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (141, '2025-08-28', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (118, '2025-07-17', 'tienda', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (48, '2026-01-23', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (20, '2026-01-15', 'web', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (18, '2025-06-23', 'web', 445000, 71200, 373800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (159, '2025-06-01', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (2, '2025-07-03', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (138, '2025-07-25', 'telefono', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (28, '2026-03-25', 'tienda', 350000, 39200, 310800, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (91, '2025-07-28', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2026-04-21', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (24, '2025-12-10', 'web', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (180, '2026-03-09', 'telefono', 525000, 84000, 441000, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (136, '2025-06-09', 'telefono', 300000, 0, 300000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (12, '2025-11-21', 'telefono', 195000, 0, 195000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (81, '2025-11-19', 'tienda', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (77, '2026-03-09', 'web', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (99, '2026-01-02', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (14, '2026-02-02', 'web', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2025-09-13', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (142, '2026-02-15', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (198, '2025-05-13', 'tienda', 745000, 74500, 670500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (40, '2026-04-21', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2025-07-05', 'web', 315000, 50400, 264600, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (34, '2026-04-22', 'telefono', 515000, 82400, 432600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (27, '2026-02-06', 'telefono', 260000, 41600, 218400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (99, '2025-09-21', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2026-04-01', 'tienda', 465000, 0, 465000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (69, '2025-10-29', 'web', 375000, 42000, 333000, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (124, '2025-07-04', 'telefono', 895000, 127090, 767910, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (118, '2025-10-05', 'web', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (85, '2025-12-16', 'telefono', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (83, '2025-07-27', 'web', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (102, '2025-12-26', 'web', 260000, 0, 260000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (84, '2025-05-09', 'web', 310000, 0, 310000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (152, '2025-09-19', 'tienda', 280000, 0, 280000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (113, '2026-01-19', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (163, '2025-08-07', 'telefono', 503000, 50300, 452700, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (19, '2026-01-22', 'telefono', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (140, '2025-07-01', 'telefono', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (28, '2026-03-24', 'tienda', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-10-07', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (3, '2026-03-31', 'telefono', 345000, 38640, 306360, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (115, '2026-01-22', 'telefono', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (89, '2026-03-15', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (187, '2025-08-17', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (90, '2025-07-25', 'web', 470000, 0, 470000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (77, '2025-11-15', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (174, '2025-07-29', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (85, '2026-02-08', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (48, '2026-02-03', 'tienda', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (116, '2025-05-08', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2026-03-10', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (94, '2025-10-20', 'telefono', 200000, 0, 200000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (153, '2026-01-13', 'tienda', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (118, '2025-05-17', 'web', 293000, 0, 293000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2025-07-04', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (96, '2025-11-09', 'telefono', 545000, 87200, 457800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (109, '2025-10-12', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (126, '2025-09-07', 'telefono', 440000, 49280, 390720, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (3, '2025-06-06', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (105, '2025-09-08', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (22, '2026-02-22', 'web', 340000, 0, 340000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (58, '2025-06-17', 'telefono', 280000, 0, 280000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2025-06-20', 'telefono', 345000, 38640, 306360, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (140, '2026-01-11', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (9, '2025-06-12', 'web', 655000, 0, 655000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (54, '2026-02-04', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (43, '2025-07-11', 'tienda', 535000, 0, 535000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (137, '2025-07-12', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2026-04-10', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (193, '2026-01-06', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (64, '2026-02-13', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (37, '2025-07-31', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (20, '2025-09-20', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (178, '2026-02-02', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2026-03-14', 'telefono', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (137, '2025-12-10', 'web', 355000, 28400, 326600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (73, '2025-08-24', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (175, '2026-02-08', 'web', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (41, '2026-04-26', 'tienda', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (41, '2025-08-18', 'tienda', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (22, '2026-05-08', 'tienda', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (161, '2025-10-14', 'web', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (1, '2025-11-28', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (3, '2026-04-16', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (19, '2026-04-05', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (77, '2025-11-15', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (136, '2025-12-18', 'web', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (161, '2026-01-27', 'telefono', 293000, 0, 293000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (23, '2025-12-25', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (110, '2025-07-08', 'web', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (142, '2025-09-11', 'web', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (53, '2025-08-31', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (166, '2025-06-09', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (62, '2025-10-28', 'telefono', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (82, '2025-05-18', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (196, '2026-03-05', 'tienda', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (4, '2026-02-15', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (109, '2025-09-02', 'telefono', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2026-03-05', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (101, '2025-08-28', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (179, '2025-05-11', 'tienda', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (112, '2025-06-13', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (31, '2026-05-05', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (89, '2026-03-27', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (192, '2025-06-07', 'tienda', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (70, '2025-09-02', 'telefono', 580000, 69600, 510400, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (117, '2025-06-11', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (41, '2025-05-24', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (190, '2025-10-24', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (94, '2025-06-13', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (58, '2026-01-26', 'web', 260000, 0, 260000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (31, '2025-09-06', 'tienda', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (103, '2025-09-27', 'web', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (142, '2026-04-15', 'telefono', 300000, 0, 300000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (119, '2026-01-11', 'tienda', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (39, '2025-08-25', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (163, '2026-02-08', 'web', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (189, '2025-07-14', 'telefono', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (126, '2026-02-24', 'telefono', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (12, '2026-02-27', 'web', 190000, 0, 190000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (192, '2026-01-05', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (152, '2025-09-09', 'tienda', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (81, '2026-01-05', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (116, '2025-12-02', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (28, '2025-08-13', 'web', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (198, '2025-06-25', 'web', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (41, '2025-06-26', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (56, '2026-04-10', 'tienda', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (102, '2025-12-14', 'tienda', 260000, 0, 260000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (116, '2025-11-05', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (36, '2025-12-10', 'tienda', 1110000, 135420, 974580, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (96, '2025-12-04', 'tienda', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (20, '2026-01-02', 'telefono', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (24, '2025-06-04', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (13, '2026-04-17', 'telefono', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (8, '2026-04-07', 'web', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2026-04-03', 'tienda', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (166, '2025-06-27', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2025-06-08', 'telefono', 255000, 20400, 234600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (98, '2025-11-30', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-10-28', 'tienda', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (153, '2025-07-02', 'tienda', 335000, 53600, 281400, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (197, '2025-09-12', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (69, '2025-08-14', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (91, '2025-08-13', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (189, '2026-02-06', 'tienda', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-12-23', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (126, '2025-07-18', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (1, '2025-12-10', 'tienda', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (83, '2025-08-09', 'tienda', 375000, 42000, 333000, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (19, '2025-09-27', 'web', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (87, '2025-12-30', 'telefono', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (167, '2025-09-12', 'telefono', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (171, '2025-06-15', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (46, '2025-12-20', 'web', 475000, 76000, 399000, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (47, '2026-02-13', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (128, '2025-06-27', 'tienda', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (43, '2025-06-02', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (3, '2026-04-06', 'web', 585000, 65520, 519480, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (185, '2026-02-08', 'tienda', 265000, 42400, 222600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (97, '2025-05-15', 'web', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (42, '2025-06-24', 'web', 655000, 0, 655000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2025-09-06', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (87, '2025-08-01', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (168, '2025-12-02', 'tienda', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (85, '2026-01-11', 'telefono', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (170, '2026-01-09', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (40, '2025-08-25', 'tienda', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (52, '2025-11-29', 'web', 805000, 98210, 706790, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (30, '2025-06-07', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (165, '2025-07-31', 'web', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (115, '2025-11-18', 'tienda', 265000, 42400, 222600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (39, '2025-05-09', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (194, '2025-11-23', 'telefono', 705000, 0, 705000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2025-09-20', 'web', 195000, 0, 195000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (31, '2025-12-26', 'tienda', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (11, '2025-10-01', 'tienda', 175000, 14000, 161000, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (82, '2025-12-10', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (142, '2026-04-29', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (29, '2026-02-16', 'telefono', 260000, 0, 260000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2026-04-11', 'web', 895000, 127090, 767910, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (99, '2026-01-12', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2025-07-26', 'telefono', 160000, 12800, 147200, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (102, '2025-08-13', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (69, '2025-10-06', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (126, '2025-08-27', 'tienda', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (191, '2025-06-06', 'web', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (49, '2026-02-28', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (15, '2026-02-09', 'web', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (35, '2025-06-08', 'tienda', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (52, '2025-10-15', 'tienda', 770000, 0, 770000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2025-06-06', 'web', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (62, '2025-06-02', 'tienda', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (89, '2026-03-03', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (8, '2026-01-07', 'tienda', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (174, '2026-01-20', 'tienda', 520000, 83200, 436800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (34, '2026-02-03', 'tienda', 190000, 0, 190000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (183, '2025-07-27', 'web', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (65, '2025-06-06', 'telefono', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (150, '2026-01-23', 'telefono', 768000, 93696, 674304, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (77, '2025-06-18', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2025-08-11', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (133, '2025-06-12', 'web', 705000, 0, 705000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (185, '2026-03-08', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (100, '2025-06-11', 'tienda', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (176, '2026-04-18', 'telefono', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (44, '2025-09-05', 'tienda', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (121, '2025-11-30', 'tienda', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (57, '2025-07-08', 'web', 120000, 0, 120000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2026-02-23', 'web', 265000, 0, 265000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (121, '2025-09-11', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (106, '2026-02-28', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (105, '2026-03-08', 'tienda', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (200, '2025-05-28', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (2, '2026-03-21', 'telefono', 240000, 0, 240000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (196, '2025-06-18', 'telefono', 710000, 100820, 609180, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (110, '2025-12-08', 'telefono', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (4, '2026-04-09', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (161, '2026-03-02', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (99, '2026-02-21', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (75, '2026-01-30', 'telefono', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (176, '2025-10-16', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (104, '2025-09-18', 'tienda', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (32, '2025-08-20', 'web', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (153, '2026-04-15', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (107, '2025-10-15', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (53, '2025-09-07', 'web', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (170, '2025-09-20', 'tienda', 270000, 0, 270000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (131, '2025-11-26', 'tienda', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (51, '2025-07-14', 'tienda', 475000, 0, 475000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (76, '2026-04-16', 'telefono', 110000, 0, 110000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (61, '2026-04-03', 'telefono', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (24, '2025-10-08', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (76, '2025-12-28', 'tienda', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2025-10-16', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (195, '2025-06-14', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (92, '2025-05-12', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (88, '2025-12-28', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (108, '2026-03-22', 'tienda', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (41, '2026-02-20', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (47, '2025-06-28', 'telefono', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (124, '2025-06-14', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2026-02-07', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (172, '2025-08-25', 'telefono', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (111, '2026-01-22', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (143, '2025-09-20', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (127, '2025-07-14', 'web', 400000, 0, 400000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2025-11-02', 'telefono', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (61, '2025-06-12', 'web', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (115, '2025-09-10', 'tienda', 110000, 0, 110000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (106, '2025-11-13', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (131, '2025-09-30', 'web', 363000, 49005, 313995, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (58, '2025-07-27', 'telefono', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (184, '2025-12-18', 'tienda', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (1, '2026-02-10', 'web', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (180, '2026-05-03', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (66, '2025-10-09', 'tienda', 310000, 0, 310000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (184, '2026-03-17', 'telefono', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (198, '2026-04-07', 'telefono', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (128, '2026-02-02', 'telefono', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (131, '2025-05-12', 'telefono', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (188, '2026-04-14', 'telefono', 380000, 51300, 328700, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (130, '2026-02-15', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (102, '2025-10-08', 'tienda', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (155, '2026-04-12', 'web', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (183, '2025-06-30', 'tienda', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (160, '2025-07-15', 'tienda', 278000, 0, 278000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (182, '2025-09-20', 'web', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2025-07-06', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (134, '2025-07-01', 'telefono', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (69, '2026-02-15', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (16, '2025-07-26', 'telefono', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (116, '2025-09-24', 'telefono', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (191, '2025-09-29', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (98, '2026-03-13', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (4, '2025-08-23', 'tienda', 350000, 56000, 294000, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2025-10-30', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (48, '2025-08-20', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2026-04-24', 'web', 415000, 0, 415000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (120, '2026-03-28', 'tienda', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2025-09-20', 'web', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (19, '2026-01-21', 'tienda', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (130, '2026-01-13', 'web', 325000, 43875, 281125, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (57, '2025-09-13', 'web', 185000, 0, 185000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (193, '2025-06-03', 'telefono', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (172, '2025-06-24', 'telefono', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (11, '2026-03-28', 'tienda', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (139, '2025-12-10', 'telefono', 515000, 61800, 453200, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (125, '2025-09-26', 'web', 583000, 82786, 500214, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (25, '2025-05-30', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (54, '2025-05-09', 'telefono', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (53, '2025-10-25', 'telefono', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (7, '2025-07-13', 'tienda', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (46, '2026-03-30', 'tienda', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (100, '2025-09-19', 'web', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2025-07-29', 'telefono', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (194, '2025-12-20', 'tienda', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (75, '2026-02-14', 'tienda', 675000, 95850, 579150, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (98, '2026-05-04', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (35, '2025-12-12', 'web', 295000, 47200, 247800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (174, '2026-02-19', 'web', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (32, '2025-05-12', 'telefono', 580000, 82360, 497640, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (79, '2025-07-04', 'tienda', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (42, '2025-06-15', 'tienda', 705000, 95175, 609825, 'KIT-009');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (172, '2026-04-26', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (75, '2025-07-23', 'telefono', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (85, '2026-02-11', 'tienda', 150000, 0, 150000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (50, '2025-05-26', 'telefono', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-11-13', 'web', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (81, '2026-03-02', 'telefono', 1010000, 143420, 866580, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2026-02-14', 'web', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (92, '2025-07-22', 'tienda', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (72, '2025-12-14', 'tienda', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (187, '2025-07-12', 'telefono', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (197, '2025-05-29', 'web', 345000, 38640, 306360, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (168, '2025-10-12', 'telefono', 665000, 106400, 558600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (119, '2025-11-10', 'web', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (170, '2025-05-28', 'telefono', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (115, '2025-11-07', 'tienda', 540000, 86400, 453600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (11, '2025-08-23', 'tienda', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (60, '2026-04-22', 'web', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (117, '2025-09-12', 'tienda', 220000, 0, 220000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (190, '2026-04-14', 'tienda', 405000, 45360, 359640, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (94, '2025-06-29', 'telefono', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (58, '2025-11-05', 'web', 215000, 0, 215000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (129, '2026-02-18', 'tienda', 350000, 39200, 310800, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (55, '2025-12-02', 'telefono', 520000, 83200, 436800, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (107, '2026-03-21', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (54, '2025-07-26', 'tienda', 265000, 0, 265000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (33, '2025-09-06', 'telefono', 255000, 0, 255000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (147, '2025-07-30', 'telefono', 530000, 84800, 445200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (185, '2025-08-06', 'tienda', 385000, 46200, 338800, 'KIT-012');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (156, '2025-12-05', 'tienda', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (150, '2025-05-20', 'telefono', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (43, '2025-08-07', 'telefono', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (59, '2025-10-25', 'tienda', 105000, 8400, 96600, 'KIT-006');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (39, '2025-12-04', 'telefono', 520000, 52000, 468000, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (24, '2026-04-15', 'telefono', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (134, '2025-09-12', 'telefono', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (59, '2025-09-21', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (109, '2025-07-28', 'tienda', 550000, 88000, 462000, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (66, '2026-05-02', 'telefono', 450000, 72000, 378000, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (134, '2025-07-02', 'telefono', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (93, '2025-11-19', 'web', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (145, '2025-05-27', 'web', 105000, 0, 105000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (142, '2026-01-03', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (65, '2025-08-29', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (192, '2025-08-18', 'tienda', 270000, 43200, 226800, 'KIT-004');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (131, '2025-12-29', 'telefono', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (100, '2025-11-03', 'web', 825000, 117150, 707850, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (23, '2025-10-11', 'telefono', 355000, 39760, 315240, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (103, '2025-09-01', 'telefono', 465000, 46500, 418500, 'KIT-011');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2025-08-30', 'tienda', 320000, 0, 320000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (50, '2025-05-20', 'telefono', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (173, '2026-04-10', 'tienda', 545000, 77390, 467610, 'KIT-007');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (71, '2025-08-14', 'web', 415000, 66400, 348600, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (133, '2025-11-28', 'tienda', 235000, 37600, 197400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (186, '2025-10-23', 'web', 335000, 0, 335000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (58, '2025-09-27', 'web', 225000, 0, 225000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2025-06-12', 'telefono', 485000, 77600, 407400, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (88, '2025-09-27', 'telefono', 730000, 89060, 640940, 'KIT-008');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (178, '2025-11-03', 'web', 175000, 0, 175000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (199, '2026-04-01', 'tienda', 275000, 0, 275000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (67, '2026-01-23', 'telefono', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (106, '2025-11-28', 'telefono', 80000, 0, 80000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (74, '2026-04-20', 'tienda', 320000, 35840, 284160, 'KIT-002');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (122, '2026-02-06', 'web', 555000, 88800, 466200, 'KIT-001');
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (128, '2025-10-24', 'web', 233000, 0, 233000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (52, '2025-05-22', 'tienda', 355000, 0, 355000, NULL);
INSERT INTO Ventas (id_cliente, fecha_venta, canal, subtotal, descuento_pesos, total, id_bundle) VALUES (21, '2025-07-06', 'telefono', 225000, 0, 225000, NULL);
GO

-- ── Insertar Detalle_Venta  ──
SET IDENTITY_INSERT Detalle_Venta OFF;
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (1, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (1, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (2, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (2, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (3, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (3, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (3, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (4, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (4, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (5, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (5, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (5, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (6, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (6, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (7, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (7, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (7, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (8, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (8, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (8, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (9, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (9, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (9, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (9, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (10, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (10, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (10, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (11, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (11, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (11, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (12, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (12, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (13, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (13, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (13, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (13, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (14, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (14, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (15, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (15, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (16, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (16, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (16, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (17, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (17, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (17, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (18, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (18, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (19, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (19, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (20, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (20, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (21, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (21, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (22, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (22, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (23, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (23, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (24, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (24, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (24, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (24, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (25, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (25, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (25, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (26, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (26, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (26, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (26, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (27, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (27, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (28, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (28, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (28, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (28, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (29, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (29, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (29, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (30, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (30, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (30, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (31, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (31, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (31, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (32, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (32, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (32, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (33, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (33, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (34, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (34, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (35, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (35, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (35, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (36, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (36, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (36, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (37, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (37, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (37, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (38, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (38, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (38, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (39, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (39, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (39, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (40, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (40, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (40, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (40, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (41, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (41, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (41, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (42, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (42, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (42, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (42, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (42, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (43, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (43, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (44, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (44, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (45, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (45, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (45, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (45, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (46, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (46, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (47, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (47, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (48, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (48, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (48, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (49, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (49, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (50, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (50, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (51, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (51, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (52, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (52, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (52, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (52, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (53, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (53, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (53, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (53, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (54, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (54, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (55, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (55, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (55, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (56, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (56, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (57, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (57, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (58, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (58, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (59, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (59, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (60, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (60, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (61, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (61, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (62, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (62, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (63, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (63, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (63, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (64, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (64, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (64, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (64, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (65, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (65, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (65, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (65, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (66, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (66, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (66, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (67, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (67, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (68, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (68, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (68, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (69, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (69, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (69, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (70, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (70, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (71, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (71, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (72, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (72, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (72, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (72, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (72, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (73, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (73, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (74, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (74, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (75, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (75, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (75, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (76, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (76, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (76, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (76, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (76, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (77, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (77, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (77, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (77, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (78, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (78, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (79, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (79, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (80, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (80, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (80, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (80, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (80, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (81, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (81, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (82, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (82, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (82, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (83, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (83, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (83, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (84, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (84, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (84, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (85, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (85, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (85, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (86, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (86, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (86, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (86, 'M_CHA', 1, 75000, 75000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (87, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (87, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (87, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (88, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (88, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (89, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (89, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (90, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (90, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (91, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (91, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (92, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (92, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (92, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (92, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (92, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (93, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (93, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (94, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (94, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (94, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (95, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (95, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (96, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (96, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (96, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (97, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (97, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (97, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (97, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (98, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (98, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (99, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (99, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (100, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (100, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (101, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (101, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (101, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (102, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (102, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (102, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (102, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (103, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (103, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (104, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (104, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (104, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (105, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (105, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (106, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (106, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (107, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (107, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (107, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (107, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (108, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (108, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (109, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (109, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (110, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (110, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (110, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (110, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (110, 'M_ALF', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (111, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (111, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (111, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (112, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (112, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (112, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (113, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (113, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (114, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (114, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (114, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (115, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (115, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (115, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (116, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (116, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (117, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (117, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (117, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (118, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (118, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (118, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (119, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (119, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (119, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (119, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (119, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (120, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (120, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (121, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (121, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (122, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (122, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (123, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (123, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (123, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (123, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (124, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (124, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (124, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (125, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (125, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (126, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (126, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (126, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (127, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (127, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (128, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (128, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (128, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (128, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (129, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (129, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (129, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (130, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (130, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (130, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (131, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (131, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (131, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (131, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (132, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (132, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (132, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (133, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (133, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (133, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (133, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (134, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (134, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (134, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (134, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (135, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (135, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (136, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (136, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (137, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (137, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (137, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (138, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (138, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (138, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (139, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (139, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (139, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (139, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (140, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (140, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (141, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (141, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (141, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (141, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (142, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (142, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (142, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (143, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (143, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (143, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (144, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (144, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (145, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (145, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (145, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (146, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (146, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (146, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (147, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (147, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (148, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (148, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (148, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (149, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (149, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (149, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (150, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (150, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (150, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (151, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (151, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (152, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (152, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (152, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (153, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (153, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (153, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (153, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (154, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (154, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (154, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (155, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (155, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (155, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (156, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (156, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (156, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (157, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (157, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (157, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (158, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (158, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (158, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (158, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (159, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (159, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (160, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (160, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (161, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (161, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (162, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (162, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (162, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (163, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (163, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (163, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (164, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (164, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (164, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (165, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (165, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (165, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (166, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (166, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (166, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (167, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (167, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (168, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (168, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (169, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (169, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (169, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (169, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (170, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (170, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (170, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (171, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (171, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (171, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (172, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (172, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (173, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (173, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (174, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (174, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (174, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (175, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (175, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (175, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (176, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (176, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (177, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (177, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (177, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (178, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (178, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (179, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (179, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (179, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (180, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (180, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (181, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (181, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (181, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (182, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (182, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (182, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (183, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (183, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (184, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (184, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (184, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (185, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (185, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (185, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (186, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (186, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (186, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (186, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (187, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (187, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (187, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (188, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (188, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (188, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (188, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (189, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (189, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (189, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (190, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (190, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (190, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (190, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (191, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (191, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (191, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (192, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (192, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (192, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (193, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (193, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (193, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (194, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (194, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (194, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (194, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (195, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (195, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (195, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (196, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (196, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (196, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (197, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (197, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (197, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (198, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (198, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (198, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (199, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (199, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (199, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (200, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (200, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (200, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (201, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (201, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (201, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (202, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (202, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (203, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (203, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (203, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (204, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (204, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (205, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (205, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (205, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (206, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (206, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (206, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (207, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (207, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (207, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (207, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (208, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (208, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (208, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (209, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (209, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (210, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (210, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (211, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (211, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (212, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (212, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (213, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (213, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (213, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (213, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (214, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (214, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (215, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (215, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (215, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (215, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (216, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (216, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (216, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (217, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (217, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (217, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (218, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (218, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (218, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (219, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (219, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (219, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (220, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (220, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (221, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (221, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (222, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (222, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (223, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (223, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (224, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (224, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (225, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (225, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (225, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (226, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (226, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (227, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (227, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (227, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (228, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (228, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (228, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (229, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (229, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (230, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (230, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (231, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (231, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (232, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (232, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (233, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (233, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (234, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (234, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (235, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (235, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (235, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (236, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (236, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (236, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (236, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (237, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (237, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (238, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (238, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (238, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (239, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (239, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (239, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (240, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (240, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (241, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (241, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (241, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (242, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (242, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (243, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (243, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (243, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (244, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (244, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (244, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (245, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (245, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (246, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (246, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (247, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (247, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (247, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (248, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (248, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (248, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (249, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (249, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (250, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (250, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (250, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (251, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (251, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (252, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (252, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (252, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (253, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (253, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (253, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (253, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (254, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (254, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (254, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (254, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (255, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (255, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (255, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (256, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (256, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (257, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (257, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (257, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (258, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (258, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (259, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (259, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (259, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (260, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (260, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (261, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (261, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (261, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (262, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (262, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (262, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (262, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (263, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (263, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (264, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (264, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (265, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (265, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (265, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (266, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (266, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (267, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (267, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (267, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (268, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (268, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (268, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (269, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (269, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (269, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (270, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (270, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (270, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (271, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (271, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (271, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (272, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (272, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (272, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (273, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (273, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (274, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (274, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (275, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (275, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (276, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (276, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (276, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (277, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (277, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (277, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (277, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (278, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (278, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (279, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (279, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (280, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (280, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (280, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (281, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (281, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (282, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (282, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (282, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (283, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (283, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (283, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (284, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (284, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (285, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (285, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (285, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (285, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (286, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (286, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (287, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (287, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (287, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (288, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (288, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (288, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (289, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (289, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (289, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (289, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (290, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (290, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (290, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (291, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (291, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (292, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (292, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (292, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (293, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (293, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (294, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (294, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (295, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (295, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (295, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (296, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (296, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (297, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (297, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (297, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (298, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (298, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (299, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (299, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (299, 'M_CHA', 1, 75000, 75000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (300, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (300, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (301, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (301, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (301, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (302, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (302, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (302, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (303, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (303, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (304, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (304, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (304, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (305, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (305, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (305, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (306, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (306, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (307, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (307, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (307, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (308, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (308, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (308, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (308, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (309, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (309, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (309, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (309, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (310, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (310, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (310, 'M_ALF', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (311, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (311, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (311, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (311, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (312, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (312, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (312, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (312, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (313, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (313, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (313, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (314, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (314, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (315, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (315, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (316, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (316, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (317, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (317, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (318, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (318, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (318, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (319, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (319, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (320, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (320, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (320, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (321, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (321, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (321, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (321, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (322, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (322, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (323, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (323, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (324, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (324, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (324, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (325, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (325, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (326, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (326, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (326, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (327, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (327, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (327, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (328, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (328, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (328, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (329, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (329, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (330, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (330, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (330, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (331, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (331, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (331, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (331, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (332, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (332, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (332, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (332, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (333, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (333, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (333, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (334, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (334, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (335, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (335, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (336, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (336, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (336, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (337, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (337, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (337, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (338, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (338, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (338, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (339, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (339, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (339, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (340, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (340, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (340, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (341, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (341, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (341, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (341, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (342, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (342, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (343, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (343, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (344, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (344, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (345, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (345, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (345, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (346, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (346, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (346, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (346, 'M_ALF', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (347, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (347, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (348, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (348, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (349, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (349, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (350, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (350, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (351, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (351, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (352, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (352, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (352, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (353, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (353, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (353, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (354, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (354, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (355, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (355, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (356, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (356, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (357, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (357, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (357, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (358, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (358, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (358, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (359, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (359, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (359, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (360, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (360, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (360, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (361, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (361, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (361, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (362, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (362, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (363, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (363, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (363, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (364, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (364, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (365, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (365, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (365, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (366, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (366, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (366, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (366, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (367, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (367, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (368, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (368, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (368, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (369, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (369, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (369, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (369, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (370, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (370, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (371, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (371, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (372, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (372, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (372, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (372, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (373, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (373, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (373, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (373, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (374, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (374, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (375, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (375, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (375, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (375, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (376, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (376, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (377, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (377, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (377, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (378, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (378, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (379, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (379, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (380, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (380, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (380, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (381, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (381, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (382, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (382, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (382, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (382, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (383, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (383, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (384, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (384, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (384, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (385, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (385, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (386, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (386, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (387, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (387, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (387, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (388, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (388, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (389, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (389, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (389, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (390, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (390, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (391, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (391, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (392, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (392, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (392, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (392, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (393, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (393, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (393, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (393, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (394, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (394, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (395, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (395, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (395, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (396, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (396, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (396, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (397, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (397, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (397, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (398, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (398, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (399, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (399, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (400, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (400, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (401, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (401, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (401, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (402, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (402, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (402, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (403, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (403, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (404, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (404, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (404, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (405, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (405, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (405, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (406, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (406, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (406, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (406, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (407, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (407, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (408, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (408, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (408, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (409, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (409, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (409, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (410, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (410, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (411, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (411, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (411, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (411, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (412, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (412, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (412, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (413, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (413, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (413, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (414, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (414, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (414, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (415, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (415, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (416, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (416, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (417, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (417, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (417, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (417, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (418, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (418, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (418, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (418, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (419, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (419, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (419, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (420, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (420, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (420, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (421, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (421, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (421, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (421, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (422, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (422, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (423, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (423, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (424, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (424, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (424, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (425, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (425, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (426, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (426, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (427, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (427, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (428, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (428, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (428, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (429, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (429, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (429, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (430, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (430, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (430, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (431, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (431, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (432, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (432, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (432, 'M_ALF', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (433, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (433, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (433, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (433, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (434, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (434, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (434, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (434, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (435, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (435, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (435, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (436, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (436, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (436, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (437, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (437, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (437, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (438, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (438, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (439, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (439, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (440, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (440, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (440, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (440, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (441, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (441, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (441, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (442, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (442, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (442, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (443, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (443, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (444, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (444, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (445, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (445, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (445, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (446, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (446, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (446, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (446, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (447, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (447, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (448, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (448, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (449, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (449, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (449, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (449, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (450, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (450, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (451, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (451, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (452, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (452, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (452, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (453, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (453, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (453, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (454, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (454, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (455, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (455, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (456, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (456, 'C_PAR', 1, 30000, 30000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (456, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (457, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (457, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (457, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (457, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (458, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (458, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (458, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (459, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (459, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (459, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (460, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (460, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (461, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (461, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (461, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (461, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (462, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (462, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (462, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (463, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (463, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (464, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (464, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (464, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (465, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (465, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (466, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (466, 'C_EXT', 1, 40000, 40000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (467, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (467, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (467, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (468, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (468, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (469, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (469, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (470, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (470, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (470, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (471, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (471, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (471, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (471, 'C_NEU', 1, 65000, 65000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (472, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (472, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (472, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (473, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (473, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (474, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (474, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (475, 'M_GPS', 1, 60000, 60000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (475, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (476, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (476, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (476, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (477, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (477, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (478, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (478, 'C_CUS', 1, 70000, 70000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (479, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (479, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (479, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (480, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (480, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (480, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (481, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (481, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (481, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (482, 'M_ROD', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (482, 'M_BOT', 1, 380000, 380000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (483, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (483, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (483, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (484, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (484, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (485, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (485, 'M_GUA', 1, 95000, 95000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (486, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (486, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (486, 'C_HUD', 1, 180000, 180000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (487, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (487, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (488, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (488, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (489, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (489, 'C_ARO', 1, 25000, 25000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (490, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (490, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (490, 'C_ALA', 1, 250000, 250000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (491, 'M_CAS', 1, 450000, 450000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (491, 'M_INT', 1, 280000, 280000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (492, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (492, 'C_LIM', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (493, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (493, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (494, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (494, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (495, 'C_LUC', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (495, 'C_CAR', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (496, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (496, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (497, 'C_TAP', 1, 120000, 120000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (497, 'C_SEN', 1, 85000, 85000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (497, 'C_FOR', 1, 200000, 200000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (497, 'C_CAM', 1, 150000, 150000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (498, 'M_EXT', 1, 38000, 38000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (498, 'M_CEL', 1, 195000, 195000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (499, 'M_BAU', 1, 220000, 220000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (499, 'M_CUB', 1, 55000, 55000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (499, 'M_CAR', 1, 45000, 45000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (499, 'M_ALF', 1, 35000, 35000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (500, 'M_MAN', 1, 130000, 130000);
INSERT INTO Detalle_Venta (id_venta, codigo_producto, cantidad, precio_unitario, subtotal_linea) VALUES (500, 'M_GUA', 1, 95000, 95000);
GO

-- ── Insertar Facturas  ──
SET IDENTITY_INSERT Facturas OFF;
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00001', 1, '2026-03-31', 'pagada', 'efectivo', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00002', 2, '2025-07-04', 'pendiente', 'efectivo', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00003', 3, '2025-05-20', 'pagada', 'tarjeta', 298200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00004', 4, '2025-09-25', 'pagada', 'cuotas', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00005', 5, '2025-09-10', 'pagada', 'tarjeta', 310000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00006', 6, '2025-08-30', 'pagada', 'tarjeta', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00007', 7, '2025-07-18', 'pendiente', 'efectivo', 506160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00008', 8, '2025-06-29', 'pagada', 'tarjeta', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00009', 9, '2026-04-19', 'pagada', 'cuotas', 670375);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00010', 10, '2026-02-11', 'pagada', 'efectivo', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00011', 11, '2025-06-21', 'pagada', 'transferencia', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00012', 12, '2026-03-06', 'pagada', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00013', 13, '2025-12-10', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00014', 14, '2025-05-24', 'pendiente', 'cuotas', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00015', 15, '2025-05-23', 'pendiente', 'efectivo', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00016', 16, '2025-06-24', 'pagada', 'cuotas', 234600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00017', 17, '2025-08-27', 'pagada', 'transferencia', 360000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00018', 18, '2025-09-04', 'pagada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00019', 19, '2026-01-21', 'pagada', 'tarjeta', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00020', 20, '2026-03-12', 'pagada', 'cuotas', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00021', 21, '2025-05-21', 'pagada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00022', 22, '2026-02-19', 'pendiente', 'cuotas', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00023', 23, '2025-08-17', 'pagada', 'cuotas', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00024', 24, '2026-04-05', 'pendiente', 'transferencia', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00025', 25, '2026-05-02', 'pagada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00026', 26, '2026-02-11', 'pagada', 'cuotas', 354650);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00027', 27, '2025-12-08', 'pagada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00028', 28, '2025-08-28', 'pendiente', 'transferencia', 516600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00029', 29, '2025-12-23', 'pagada', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00030', 30, '2026-03-05', 'pagada', 'cuotas', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00031', 31, '2025-09-27', 'pagada', 'efectivo', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00032', 32, '2025-05-11', 'pagada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00033', 33, '2025-07-28', 'pagada', 'tarjeta', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00034', 34, '2026-04-30', 'pendiente', 'efectivo', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00035', 35, '2025-12-10', 'pagada', 'efectivo', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00036', 36, '2025-10-29', 'pendiente', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00037', 37, '2025-09-27', 'pendiente', 'cuotas', 680450);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00038', 38, '2025-07-26', 'anulada', 'tarjeta', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00039', 39, '2025-08-26', 'anulada', 'tarjeta', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00040', 40, '2025-10-27', 'anulada', 'transferencia', 558600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00041', 41, '2025-06-29', 'pagada', 'efectivo', 240000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00042', 42, '2025-06-24', 'anulada', 'transferencia', 512400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00043', 43, '2025-11-18', 'pagada', 'transferencia', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00044', 44, '2025-06-26', 'pagada', 'cuotas', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00045', 45, '2025-11-07', 'pendiente', 'transferencia', 523325);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00046', 46, '2025-10-31', 'pendiente', 'cuotas', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00047', 47, '2026-03-13', 'pagada', 'transferencia', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00048', 48, '2025-09-20', 'pagada', 'transferencia', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00049', 49, '2025-05-30', 'pagada', 'efectivo', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00050', 50, '2025-12-29', 'pagada', 'transferencia', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00051', 51, '2026-02-06', 'anulada', 'cuotas', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00052', 52, '2025-07-10', 'pendiente', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00053', 53, '2025-11-17', 'pagada', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00054', 54, '2025-06-17', 'pagada', 'efectivo', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00055', 55, '2026-02-14', 'pagada', 'efectivo', 138000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00056', 56, '2025-10-05', 'anulada', 'transferencia', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00057', 57, '2026-03-25', 'anulada', 'efectivo', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00058', 58, '2026-03-20', 'pagada', 'tarjeta', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00059', 59, '2025-11-09', 'pagada', 'efectivo', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00060', 60, '2026-02-27', 'pendiente', 'tarjeta', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00061', 61, '2025-08-14', 'pagada', 'tarjeta', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00062', 62, '2026-05-03', 'pagada', 'cuotas', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00063', 63, '2025-06-12', 'pagada', 'efectivo', 635000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00064', 64, '2025-05-31', 'pagada', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00065', 65, '2026-04-11', 'pagada', 'efectivo', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00066', 66, '2025-09-01', 'pagada', 'tarjeta', 313000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00067', 67, '2025-10-03', 'pagada', 'cuotas', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00068', 68, '2025-06-17', 'anulada', 'cuotas', 420000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00069', 69, '2025-09-04', 'anulada', 'transferencia', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00070', 70, '2025-06-28', 'pendiente', 'transferencia', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00071', 71, '2025-11-18', 'pagada', 'cuotas', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00072', 72, '2025-09-27', 'pagada', 'tarjeta', 1055340);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00073', 73, '2025-12-26', 'anulada', 'transferencia', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00074', 74, '2026-03-29', 'pendiente', 'transferencia', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00075', 75, '2025-11-10', 'pagada', 'transferencia', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00076', 76, '2025-07-30', 'anulada', 'transferencia', 491400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00077', 77, '2025-11-13', 'anulada', 'tarjeta', 319200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00078', 78, '2025-11-05', 'pagada', 'efectivo', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00079', 79, '2025-08-23', 'pagada', 'efectivo', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00080', 80, '2026-04-16', 'pagada', 'transferencia', 899184);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00081', 81, '2025-09-21', 'anulada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00082', 82, '2026-05-02', 'pendiente', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00083', 83, '2026-04-22', 'pagada', 'efectivo', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00084', 84, '2026-04-04', 'pagada', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00085', 85, '2025-06-13', 'pendiente', 'transferencia', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00086', 86, '2026-03-15', 'pagada', 'tarjeta', 643500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00087', 87, '2026-03-29', 'pagada', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00088', 88, '2025-08-03', 'anulada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00089', 89, '2026-02-05', 'pendiente', 'transferencia', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00090', 90, '2025-09-10', 'pagada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00091', 91, '2025-07-30', 'pagada', 'tarjeta', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00092', 92, '2025-12-30', 'anulada', 'transferencia', 504000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00093', 93, '2025-11-18', 'anulada', 'tarjeta', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00094', 94, '2025-09-23', 'anulada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00095', 95, '2026-03-31', 'pagada', 'tarjeta', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00096', 96, '2026-04-25', 'pendiente', 'transferencia', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00097', 97, '2026-02-17', 'anulada', 'tarjeta', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00098', 98, '2025-08-28', 'pagada', 'tarjeta', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00099', 99, '2026-04-23', 'pagada', 'cuotas', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00100', 100, '2025-10-21', 'anulada', 'cuotas', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00101', 101, '2025-06-05', 'pagada', 'efectivo', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00102', 102, '2025-09-02', 'pagada', 'efectivo', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00103', 103, '2025-05-24', 'pagada', 'transferencia', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00104', 104, '2025-10-16', 'pendiente', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00105', 105, '2025-11-29', 'pagada', 'tarjeta', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00106', 106, '2025-09-22', 'pendiente', 'tarjeta', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00107', 107, '2025-06-10', 'pendiente', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00108', 108, '2025-08-24', 'pagada', 'tarjeta', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00109', 109, '2026-02-22', 'pendiente', 'efectivo', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00110', 110, '2025-10-16', 'anulada', 'efectivo', 896610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00111', 111, '2025-08-24', 'pagada', 'efectivo', 288000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00112', 112, '2026-04-08', 'anulada', 'transferencia', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00113', 113, '2026-01-18', 'pagada', 'tarjeta', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00114', 114, '2025-11-26', 'anulada', 'tarjeta', 260000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00115', 115, '2026-04-02', 'pagada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00116', 116, '2025-12-28', 'pagada', 'cuotas', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00117', 117, '2025-07-20', 'pagada', 'tarjeta', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00118', 118, '2025-09-20', 'anulada', 'tarjeta', 400000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00119', 119, '2025-07-18', 'pendiente', 'transferencia', 905190);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00120', 120, '2025-09-11', 'pagada', 'cuotas', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00121', 121, '2026-02-19', 'anulada', 'tarjeta', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00122', 122, '2026-02-07', 'pagada', 'tarjeta', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00123', 123, '2025-09-19', 'anulada', 'tarjeta', 302400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00124', 124, '2026-03-03', 'pendiente', 'transferencia', 185000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00125', 125, '2025-12-13', 'pagada', 'cuotas', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00126', 126, '2026-03-02', 'pagada', 'cuotas', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00127', 127, '2025-11-28', 'pagada', 'cuotas', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00128', 128, '2025-11-09', 'pagada', 'cuotas', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00129', 129, '2025-08-28', 'pendiente', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00130', 130, '2025-07-17', 'pagada', 'cuotas', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00131', 131, '2026-01-23', 'anulada', 'efectivo', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00132', 132, '2026-01-15', 'pagada', 'tarjeta', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00133', 133, '2025-06-23', 'pagada', 'efectivo', 373800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00134', 134, '2025-06-01', 'pendiente', 'efectivo', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00135', 135, '2025-07-03', 'anulada', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00136', 136, '2025-07-25', 'pendiente', 'tarjeta', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00137', 137, '2026-03-25', 'anulada', 'transferencia', 310800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00138', 138, '2025-07-28', 'pendiente', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00139', 139, '2026-04-21', 'pagada', 'efectivo', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00140', 140, '2025-12-10', 'pagada', 'efectivo', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00141', 141, '2026-03-09', 'pagada', 'efectivo', 441000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00142', 142, '2025-06-09', 'pendiente', 'transferencia', 300000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00143', 143, '2025-11-21', 'pagada', 'tarjeta', 195000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00144', 144, '2025-11-19', 'pendiente', 'efectivo', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00145', 145, '2026-03-09', 'anulada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00146', 146, '2026-01-02', 'pagada', 'transferencia', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00147', 147, '2026-02-02', 'anulada', 'cuotas', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00148', 148, '2025-09-13', 'pagada', 'transferencia', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00149', 149, '2026-02-15', 'pendiente', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00150', 150, '2025-05-13', 'pagada', 'transferencia', 670500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00151', 151, '2026-04-21', 'pendiente', 'transferencia', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00152', 152, '2025-07-05', 'pagada', 'efectivo', 264600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00153', 153, '2026-04-22', 'anulada', 'cuotas', 432600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00154', 154, '2026-02-06', 'anulada', 'transferencia', 218400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00155', 155, '2025-09-21', 'anulada', 'tarjeta', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00156', 156, '2026-04-01', 'pagada', 'transferencia', 465000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00157', 157, '2025-10-29', 'pendiente', 'transferencia', 333000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00158', 158, '2025-07-04', 'pendiente', 'tarjeta', 767910);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00159', 159, '2025-10-05', 'anulada', 'cuotas', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00160', 160, '2025-12-16', 'pagada', 'transferencia', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00161', 161, '2025-07-27', 'pagada', 'tarjeta', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00162', 162, '2025-12-26', 'anulada', 'tarjeta', 260000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00163', 163, '2025-05-09', 'pagada', 'tarjeta', 310000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00164', 164, '2025-09-19', 'pendiente', 'tarjeta', 280000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00165', 165, '2026-01-19', 'pendiente', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00166', 166, '2025-08-07', 'pendiente', 'cuotas', 452700);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00167', 167, '2026-01-22', 'pendiente', 'cuotas', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00168', 168, '2025-07-01', 'anulada', 'efectivo', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00169', 169, '2026-03-24', 'anulada', 'efectivo', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00170', 170, '2025-10-07', 'pendiente', 'efectivo', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00171', 171, '2026-03-31', 'anulada', 'tarjeta', 306360);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00172', 172, '2026-01-22', 'anulada', 'tarjeta', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00173', 173, '2026-03-15', 'pagada', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00174', 174, '2025-08-17', 'pagada', 'cuotas', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00175', 175, '2025-07-25', 'pagada', 'efectivo', 470000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00176', 176, '2025-11-15', 'pagada', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00177', 177, '2025-07-29', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00178', 178, '2026-02-08', 'pendiente', 'tarjeta', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00179', 179, '2026-02-03', 'anulada', 'tarjeta', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00180', 180, '2025-05-08', 'pagada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00181', 181, '2026-03-10', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00182', 182, '2025-10-20', 'pendiente', 'transferencia', 200000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00183', 183, '2026-01-13', 'pagada', 'transferencia', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00184', 184, '2025-05-17', 'anulada', 'efectivo', 293000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00185', 185, '2025-07-04', 'pagada', 'tarjeta', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00186', 186, '2025-11-09', 'pagada', 'cuotas', 457800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00187', 187, '2025-10-12', 'pagada', 'tarjeta', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00188', 188, '2025-09-07', 'pagada', 'transferencia', 390720);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00189', 189, '2025-06-06', 'anulada', 'cuotas', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00190', 190, '2025-09-08', 'pendiente', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00191', 191, '2026-02-22', 'pagada', 'transferencia', 340000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00192', 192, '2025-06-17', 'pendiente', 'efectivo', 280000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00193', 193, '2025-06-20', 'pagada', 'cuotas', 306360);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00194', 194, '2026-01-11', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00195', 195, '2025-06-12', 'pagada', 'tarjeta', 655000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00196', 196, '2026-02-04', 'anulada', 'cuotas', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00197', 197, '2025-07-11', 'anulada', 'transferencia', 535000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00198', 198, '2025-07-12', 'pagada', 'transferencia', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00199', 199, '2026-04-10', 'pagada', 'tarjeta', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00200', 200, '2026-01-06', 'pagada', 'tarjeta', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00201', 201, '2026-02-13', 'pendiente', 'cuotas', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00202', 202, '2025-07-31', 'pendiente', 'cuotas', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00203', 203, '2025-09-20', 'anulada', 'transferencia', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00204', 204, '2026-02-02', 'pagada', 'efectivo', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00205', 205, '2026-03-14', 'pagada', 'efectivo', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00206', 206, '2025-12-10', 'pagada', 'transferencia', 326600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00207', 207, '2025-08-24', 'pendiente', 'transferencia', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00208', 208, '2026-02-08', 'pagada', 'efectivo', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00209', 209, '2026-04-26', 'pagada', 'transferencia', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00210', 210, '2025-08-18', 'pagada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00211', 211, '2026-05-08', 'pagada', 'cuotas', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00212', 212, '2025-10-14', 'pagada', 'efectivo', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00213', 213, '2025-11-28', 'pagada', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00214', 214, '2026-04-16', 'pagada', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00215', 215, '2026-04-05', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00216', 216, '2025-11-15', 'pagada', 'efectivo', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00217', 217, '2025-12-18', 'pagada', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00218', 218, '2026-01-27', 'pendiente', 'tarjeta', 293000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00219', 219, '2025-12-25', 'pendiente', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00220', 220, '2025-07-08', 'pagada', 'tarjeta', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00221', 221, '2025-09-11', 'pagada', 'transferencia', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00222', 222, '2025-08-31', 'pendiente', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00223', 223, '2025-06-09', 'pendiente', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00224', 224, '2025-10-28', 'pagada', 'transferencia', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00225', 225, '2025-05-18', 'pagada', 'tarjeta', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00226', 226, '2026-03-05', 'anulada', 'efectivo', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00227', 227, '2026-02-15', 'pagada', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00228', 228, '2025-09-02', 'anulada', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00229', 229, '2026-03-05', 'pagada', 'transferencia', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00230', 230, '2025-08-28', 'pagada', 'transferencia', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00231', 231, '2025-05-11', 'pagada', 'efectivo', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00232', 232, '2025-06-13', 'pagada', 'tarjeta', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00233', 233, '2026-05-05', 'pagada', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00234', 234, '2026-03-27', 'pagada', 'tarjeta', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00235', 235, '2025-06-07', 'pagada', 'cuotas', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00236', 236, '2025-09-02', 'pagada', 'cuotas', 510400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00237', 237, '2025-06-11', 'pagada', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00238', 238, '2025-05-24', 'pagada', 'tarjeta', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00239', 239, '2025-10-24', 'pagada', 'cuotas', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00240', 240, '2025-06-13', 'anulada', 'cuotas', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00241', 241, '2026-01-26', 'pagada', 'transferencia', 260000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00242', 242, '2025-09-06', 'pagada', 'efectivo', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00243', 243, '2025-09-27', 'pagada', 'efectivo', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00244', 244, '2026-04-15', 'pagada', 'tarjeta', 300000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00245', 245, '2026-01-11', 'anulada', 'tarjeta', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00246', 246, '2025-08-25', 'anulada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00247', 247, '2026-02-08', 'pagada', 'cuotas', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00248', 248, '2025-07-14', 'pagada', 'cuotas', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00249', 249, '2026-02-24', 'pagada', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00250', 250, '2026-02-27', 'pagada', 'cuotas', 190000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00251', 251, '2026-01-05', 'pendiente', 'efectivo', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00252', 252, '2025-09-09', 'pagada', 'transferencia', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00253', 253, '2026-01-05', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00254', 254, '2025-12-02', 'pagada', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00255', 255, '2025-08-13', 'pagada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00256', 256, '2025-06-25', 'pagada', 'efectivo', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00257', 257, '2025-06-26', 'anulada', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00258', 258, '2026-04-10', 'pagada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00259', 259, '2025-12-14', 'pagada', 'cuotas', 260000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00260', 260, '2025-11-05', 'pendiente', 'efectivo', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00261', 261, '2025-12-10', 'pagada', 'cuotas', 974580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00262', 262, '2025-12-04', 'anulada', 'transferencia', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00263', 263, '2026-01-02', 'pendiente', 'tarjeta', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00264', 264, '2025-06-04', 'pagada', 'cuotas', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00265', 265, '2026-04-17', 'pendiente', 'cuotas', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00266', 266, '2026-04-07', 'pagada', 'tarjeta', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00267', 267, '2026-04-03', 'anulada', 'tarjeta', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00268', 268, '2025-06-27', 'pagada', 'efectivo', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00269', 269, '2025-06-08', 'pagada', 'efectivo', 234600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00270', 270, '2025-11-30', 'pendiente', 'transferencia', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00271', 271, '2025-10-28', 'pagada', 'transferencia', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00272', 272, '2025-07-02', 'pendiente', 'transferencia', 281400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00273', 273, '2025-09-12', 'pagada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00274', 274, '2025-08-14', 'anulada', 'cuotas', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00275', 275, '2025-08-13', 'pagada', 'transferencia', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00276', 276, '2026-02-06', 'pagada', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00277', 277, '2025-12-23', 'pagada', 'tarjeta', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00278', 278, '2025-07-18', 'pagada', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00279', 279, '2025-12-10', 'pagada', 'tarjeta', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00280', 280, '2025-08-09', 'pagada', 'transferencia', 333000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00281', 281, '2025-09-27', 'anulada', 'efectivo', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00282', 282, '2025-12-30', 'pendiente', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00283', 283, '2025-09-12', 'pagada', 'tarjeta', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00284', 284, '2025-06-15', 'pagada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00285', 285, '2025-12-20', 'anulada', 'efectivo', 399000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00286', 286, '2026-02-13', 'anulada', 'efectivo', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00287', 287, '2025-06-27', 'pagada', 'transferencia', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00288', 288, '2025-06-02', 'pagada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00289', 289, '2026-04-06', 'pagada', 'efectivo', 519480);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00290', 290, '2026-02-08', 'pendiente', 'cuotas', 222600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00291', 291, '2025-05-15', 'anulada', 'tarjeta', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00292', 292, '2025-06-24', 'pagada', 'transferencia', 655000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00293', 293, '2025-09-06', 'pagada', 'efectivo', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00294', 294, '2025-08-01', 'pagada', 'cuotas', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00295', 295, '2025-12-02', 'pagada', 'efectivo', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00296', 296, '2026-01-11', 'anulada', 'transferencia', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00297', 297, '2026-01-09', 'anulada', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00298', 298, '2025-08-25', 'pagada', 'cuotas', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00299', 299, '2025-11-29', 'pagada', 'cuotas', 706790);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00300', 300, '2025-06-07', 'pagada', 'efectivo', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00301', 301, '2025-07-31', 'pagada', 'tarjeta', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00302', 302, '2025-11-18', 'pagada', 'efectivo', 222600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00303', 303, '2025-05-09', 'pagada', 'cuotas', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00304', 304, '2025-11-23', 'pendiente', 'cuotas', 705000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00305', 305, '2025-09-20', 'pagada', 'tarjeta', 195000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00306', 306, '2025-12-26', 'pagada', 'tarjeta', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00307', 307, '2025-10-01', 'pagada', 'transferencia', 161000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00308', 308, '2025-12-10', 'pendiente', 'cuotas', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00309', 309, '2026-04-29', 'pagada', 'cuotas', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00310', 310, '2026-02-16', 'pagada', 'efectivo', 260000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00311', 311, '2026-04-11', 'pendiente', 'transferencia', 767910);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00312', 312, '2026-01-12', 'pagada', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00313', 313, '2025-07-26', 'pendiente', 'efectivo', 147200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00314', 314, '2025-08-13', 'pagada', 'cuotas', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00315', 315, '2025-10-06', 'pagada', 'transferencia', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00316', 316, '2025-08-27', 'pagada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00317', 317, '2025-06-06', 'pendiente', 'efectivo', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00318', 318, '2026-02-28', 'pendiente', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00319', 319, '2026-02-09', 'anulada', 'cuotas', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00320', 320, '2025-06-08', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00321', 321, '2025-10-15', 'pagada', 'tarjeta', 770000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00322', 322, '2025-06-06', 'pagada', 'efectivo', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00323', 323, '2025-06-02', 'pendiente', 'transferencia', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00324', 324, '2026-03-03', 'pagada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00325', 325, '2026-01-07', 'pagada', 'tarjeta', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00326', 326, '2026-01-20', 'pagada', 'cuotas', 436800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00327', 327, '2026-02-03', 'pagada', 'transferencia', 190000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00328', 328, '2025-07-27', 'pagada', 'cuotas', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00329', 329, '2025-06-06', 'anulada', 'cuotas', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00330', 330, '2026-01-23', 'anulada', 'transferencia', 674304);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00331', 331, '2025-06-18', 'pagada', 'transferencia', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00332', 332, '2025-08-11', 'pagada', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00333', 333, '2025-06-12', 'pagada', 'tarjeta', 705000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00334', 334, '2026-03-08', 'pendiente', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00335', 335, '2025-06-11', 'pagada', 'tarjeta', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00336', 336, '2026-04-18', 'pagada', 'transferencia', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00337', 337, '2025-09-05', 'pagada', 'efectivo', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00338', 338, '2025-11-30', 'pagada', 'efectivo', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00339', 339, '2025-07-08', 'pagada', 'transferencia', 120000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00340', 340, '2026-02-23', 'pagada', 'efectivo', 265000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00341', 341, '2025-09-11', 'anulada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00342', 342, '2026-02-28', 'pagada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00343', 343, '2026-03-08', 'pagada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00344', 344, '2025-05-28', 'pagada', 'efectivo', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00345', 345, '2026-03-21', 'pagada', 'cuotas', 240000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00346', 346, '2025-06-18', 'pendiente', 'cuotas', 609180);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00347', 347, '2025-12-08', 'pagada', 'transferencia', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00348', 348, '2026-04-09', 'pagada', 'efectivo', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00349', 349, '2026-03-02', 'pagada', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00350', 350, '2026-02-21', 'pagada', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00351', 351, '2026-01-30', 'pagada', 'cuotas', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00352', 352, '2025-10-16', 'pagada', 'tarjeta', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00353', 353, '2025-09-18', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00354', 354, '2025-08-20', 'pagada', 'efectivo', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00355', 355, '2026-04-15', 'pagada', 'efectivo', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00356', 356, '2025-10-15', 'pendiente', 'tarjeta', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00357', 357, '2025-09-07', 'pendiente', 'efectivo', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00358', 358, '2025-09-20', 'pendiente', 'efectivo', 270000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00359', 359, '2025-11-26', 'pagada', 'cuotas', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00360', 360, '2025-07-14', 'pagada', 'cuotas', 475000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00361', 361, '2026-04-16', 'pendiente', 'transferencia', 110000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00362', 362, '2026-04-03', 'pendiente', 'tarjeta', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00363', 363, '2025-10-08', 'pagada', 'cuotas', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00364', 364, '2025-12-28', 'pagada', 'transferencia', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00365', 365, '2025-10-16', 'pagada', 'efectivo', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00366', 366, '2025-06-14', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00367', 367, '2025-05-12', 'pagada', 'transferencia', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00368', 368, '2025-12-28', 'pendiente', 'cuotas', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00369', 369, '2026-03-22', 'pagada', 'efectivo', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00370', 370, '2026-02-20', 'anulada', 'cuotas', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00371', 371, '2025-06-28', 'pagada', 'tarjeta', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00372', 372, '2025-06-14', 'pagada', 'efectivo', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00373', 373, '2026-02-07', 'anulada', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00374', 374, '2025-08-25', 'anulada', 'efectivo', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00375', 375, '2026-01-22', 'pendiente', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00376', 376, '2025-09-20', 'pagada', 'cuotas', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00377', 377, '2025-07-14', 'pagada', 'transferencia', 400000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00378', 378, '2025-11-02', 'pendiente', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00379', 379, '2025-06-12', 'pagada', 'cuotas', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00380', 380, '2025-09-10', 'pagada', 'cuotas', 110000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00381', 381, '2025-11-13', 'anulada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00382', 382, '2025-09-30', 'pagada', 'efectivo', 313995);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00383', 383, '2025-07-27', 'anulada', 'cuotas', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00384', 384, '2025-12-18', 'pagada', 'tarjeta', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00385', 385, '2026-02-10', 'anulada', 'transferencia', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00386', 386, '2026-05-03', 'pendiente', 'efectivo', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00387', 387, '2025-10-09', 'pendiente', 'tarjeta', 310000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00388', 388, '2026-03-17', 'anulada', 'efectivo', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00389', 389, '2026-04-07', 'anulada', 'tarjeta', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00390', 390, '2026-02-02', 'pendiente', 'cuotas', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00391', 391, '2025-05-12', 'anulada', 'tarjeta', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00392', 392, '2026-04-14', 'anulada', 'transferencia', 328700);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00393', 393, '2026-02-15', 'pagada', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00394', 394, '2025-10-08', 'pagada', 'cuotas', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00395', 395, '2026-04-12', 'anulada', 'transferencia', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00396', 396, '2025-06-30', 'pagada', 'tarjeta', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00397', 397, '2025-07-15', 'pagada', 'transferencia', 278000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00398', 398, '2025-09-20', 'anulada', 'cuotas', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00399', 399, '2025-07-06', 'pendiente', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00400', 400, '2025-07-01', 'pagada', 'tarjeta', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00401', 401, '2026-02-15', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00402', 402, '2025-07-26', 'pagada', 'transferencia', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00403', 403, '2025-09-24', 'anulada', 'tarjeta', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00404', 404, '2025-09-29', 'pagada', 'efectivo', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00405', 405, '2026-03-13', 'anulada', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00406', 406, '2025-08-23', 'pagada', 'tarjeta', 294000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00407', 407, '2025-10-30', 'pagada', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00408', 408, '2025-08-20', 'pagada', 'cuotas', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00409', 409, '2026-04-24', 'pagada', 'transferencia', 415000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00410', 410, '2026-03-28', 'pagada', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00411', 411, '2025-09-20', 'pendiente', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00412', 412, '2026-01-21', 'pagada', 'efectivo', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00413', 413, '2026-01-13', 'pagada', 'transferencia', 281125);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00414', 414, '2025-09-13', 'pagada', 'tarjeta', 185000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00415', 415, '2025-06-03', 'pagada', 'efectivo', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00416', 416, '2025-06-24', 'anulada', 'tarjeta', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00417', 417, '2026-03-28', 'pendiente', 'transferencia', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00418', 418, '2025-12-10', 'anulada', 'cuotas', 453200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00419', 419, '2025-09-26', 'anulada', 'efectivo', 500214);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00420', 420, '2025-05-30', 'pagada', 'efectivo', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00421', 421, '2025-05-09', 'pendiente', 'efectivo', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00422', 422, '2025-10-25', 'pagada', 'tarjeta', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00423', 423, '2025-07-13', 'pagada', 'efectivo', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00424', 424, '2026-03-30', 'pagada', 'cuotas', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00425', 425, '2025-09-19', 'pagada', 'cuotas', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00426', 426, '2025-07-29', 'anulada', 'efectivo', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00427', 427, '2025-12-20', 'pagada', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00428', 428, '2026-02-14', 'pagada', 'cuotas', 579150);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00429', 429, '2026-05-04', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00430', 430, '2025-12-12', 'pagada', 'transferencia', 247800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00431', 431, '2026-02-19', 'pagada', 'tarjeta', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00432', 432, '2025-05-12', 'anulada', 'efectivo', 497640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00433', 433, '2025-07-04', 'pendiente', 'tarjeta', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00434', 434, '2025-06-15', 'pagada', 'tarjeta', 609825);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00435', 435, '2026-04-26', 'pendiente', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00436', 436, '2025-07-23', 'anulada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00437', 437, '2026-02-11', 'pagada', 'efectivo', 150000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00438', 438, '2025-05-26', 'pagada', 'tarjeta', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00439', 439, '2025-11-13', 'pagada', 'efectivo', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00440', 440, '2026-03-02', 'pendiente', 'transferencia', 866580);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00441', 441, '2026-02-14', 'pendiente', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00442', 442, '2025-07-22', 'pagada', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00443', 443, '2025-12-14', 'pagada', 'efectivo', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00444', 444, '2025-07-12', 'pagada', 'cuotas', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00445', 445, '2025-05-29', 'anulada', 'cuotas', 306360);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00446', 446, '2025-10-12', 'pagada', 'tarjeta', 558600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00447', 447, '2025-11-10', 'anulada', 'efectivo', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00448', 448, '2025-05-28', 'pagada', 'tarjeta', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00449', 449, '2025-11-07', 'pendiente', 'transferencia', 453600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00450', 450, '2025-08-23', 'pagada', 'transferencia', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00451', 451, '2026-04-22', 'pendiente', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00452', 452, '2025-09-12', 'anulada', 'transferencia', 220000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00453', 453, '2026-04-14', 'pendiente', 'cuotas', 359640);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00454', 454, '2025-06-29', 'pagada', 'cuotas', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00455', 455, '2025-11-05', 'pendiente', 'efectivo', 215000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00456', 456, '2026-02-18', 'anulada', 'transferencia', 310800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00457', 457, '2025-12-02', 'pagada', 'tarjeta', 436800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00458', 458, '2026-03-21', 'pendiente', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00459', 459, '2025-07-26', 'pagada', 'efectivo', 265000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00460', 460, '2025-09-06', 'anulada', 'efectivo', 255000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00461', 461, '2025-07-30', 'pendiente', 'efectivo', 445200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00462', 462, '2025-08-06', 'pagada', 'cuotas', 338800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00463', 463, '2025-12-05', 'pendiente', 'tarjeta', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00464', 464, '2025-05-20', 'anulada', 'transferencia', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00465', 465, '2025-08-07', 'anulada', 'efectivo', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00466', 466, '2025-10-25', 'pagada', 'cuotas', 96600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00467', 467, '2025-12-04', 'pagada', 'efectivo', 468000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00468', 468, '2026-04-15', 'pagada', 'cuotas', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00469', 469, '2025-09-12', 'anulada', 'cuotas', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00470', 470, '2025-09-21', 'anulada', 'efectivo', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00471', 471, '2025-07-28', 'pagada', 'cuotas', 462000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00472', 472, '2026-05-02', 'anulada', 'efectivo', 378000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00473', 473, '2025-07-02', 'pagada', 'cuotas', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00474', 474, '2025-11-19', 'pagada', 'cuotas', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00475', 475, '2025-05-27', 'pagada', 'cuotas', 105000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00476', 476, '2026-01-03', 'anulada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00477', 477, '2025-08-29', 'pagada', 'efectivo', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00478', 478, '2025-08-18', 'pagada', 'tarjeta', 226800);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00479', 479, '2025-12-29', 'pagada', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00480', 480, '2025-11-03', 'anulada', 'cuotas', 707850);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00481', 481, '2025-10-11', 'pagada', 'cuotas', 315240);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00482', 482, '2025-09-01', 'anulada', 'efectivo', 418500);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00483', 483, '2025-08-30', 'pagada', 'transferencia', 320000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00484', 484, '2025-05-20', 'pagada', 'tarjeta', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00485', 485, '2026-04-10', 'pagada', 'efectivo', 467610);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00486', 486, '2025-08-14', 'pendiente', 'tarjeta', 348600);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00487', 487, '2025-11-28', 'anulada', 'transferencia', 197400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00488', 488, '2025-10-23', 'pagada', 'transferencia', 335000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00489', 489, '2025-09-27', 'anulada', 'efectivo', 225000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00490', 490, '2025-06-12', 'pagada', 'transferencia', 407400);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00491', 491, '2025-09-27', 'anulada', 'transferencia', 640940);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00492', 492, '2025-11-03', 'pagada', 'transferencia', 175000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00493', 493, '2026-04-01', 'pendiente', 'efectivo', 275000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00494', 494, '2026-01-23', 'pagada', 'transferencia', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00495', 495, '2025-11-28', 'pagada', 'tarjeta', 80000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00496', 496, '2026-04-20', 'anulada', 'tarjeta', 284160);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00497', 497, '2026-02-06', 'pagada', 'tarjeta', 466200);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00498', 498, '2025-10-24', 'pagada', 'tarjeta', 233000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00499', 499, '2025-05-22', 'pagada', 'efectivo', 355000);
INSERT INTO Facturas (numero_factura, id_venta, fecha_emision, estado, metodo_pago, total_factura) VALUES ('FAC-00500', 500, '2025-07-06', 'pagada', 'efectivo', 225000);
GO

-- ── Insertar Inventario  ──
SET IDENTITY_INSERT Inventario OFF;
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_TAP', 116, 12, 127, 'Sucursal Cali', '2025-09-11', '2025-08-31');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_SEN', 120, 14, 191, 'Sucursal Medellin', '2026-02-22', '2025-10-14');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_FOR', 105, 13, 115, 'Sucursal Medellin', '2025-05-20', '2025-07-26');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_CAM', 81, 7, 86, 'Sucursal Cali', '2025-12-09', '2025-11-24');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_LUC', 69, 13, 84, 'Sucursal Cali', '2025-10-08', '2026-01-10');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_CAR', 118, 15, 179, 'Bodega Principal Bogota', '2026-01-17', '2025-07-30');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_ALA', 97, 13, 138, 'Sucursal Medellin', '2025-11-14', '2026-03-23');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_PAR', 9, 15, 106, 'Sucursal Medellin', '2025-08-06', '2025-10-09');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_ARO', 49, 10, 158, 'Sucursal Medellin', '2025-05-23', '2026-01-10');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_LIM', 41, 8, 114, 'Sucursal Medellin', '2025-05-01', '2026-02-22');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_CUS', 54, 7, 143, 'Sucursal Medellin', '2026-01-31', '2025-09-09');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_HUD', 97, 10, 126, 'Sucursal Medellin', '2025-11-03', '2026-01-07');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_NEU', 31, 14, 96, 'Sucursal Cali', '2025-06-05', '2025-11-17');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('C_EXT', 112, 6, 172, 'Sucursal Medellin', '2025-10-08', '2025-08-03');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_CAS', 79, 11, 189, 'Sucursal Medellin', '2025-10-01', '2026-02-15');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_GUA', 110, 7, 140, 'Bodega Principal Bogota', '2025-10-06', '2025-12-27');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_CHA', 71, 7, 194, 'Sucursal Cali', '2025-10-15', '2025-12-24');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_INT', 100, 10, 180, 'Sucursal Medellin', '2025-09-29', '2026-03-11');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_BAU', 79, 14, 86, 'Sucursal Medellin', '2025-07-05', '2025-09-07');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_CAR', 28, 5, 107, 'Sucursal Medellin', '2025-12-02', '2025-12-12');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_GPS', 88, 6, 137, 'Sucursal Cali', '2025-07-29', '2026-04-12');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_CUB', 54, 10, 151, 'Sucursal Cali', '2026-02-16', '2025-11-02');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_MAN', 52, 5, 132, 'Bodega Principal Bogota', '2025-11-24', '2026-03-08');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_ALF', 94, 14, 105, 'Sucursal Cali', '2025-05-01', '2025-11-03');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_EXT', 91, 13, 102, 'Sucursal Medellin', '2025-09-24', '2025-09-16');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_CEL', 94, 13, 142, 'Sucursal Cali', '2025-12-07', '2026-03-24');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_ROD', 18, 11, 158, 'Sucursal Medellin', '2025-10-12', '2026-01-25');
INSERT INTO Inventario (codigo_producto, stock_actual, stock_minimo, stock_maximo, ubicacion, fecha_ultima_entrada, fecha_ultima_salida) VALUES ('M_BOT', 26, 7, 161, 'Sucursal Medellin', '2025-12-13', '2026-01-13');
GO




--  MEJORAS SOLICITADAS 
-- Incluye: métricas inteligentes, consultas analíticas,
-- modelos de recomendación basados en lift/confianza,
-- análisis automatizado y lógica de decisión basada en datos
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- VISTAS ANALÍTICAS (reemplazar cálculos manuales repetidos)
-- ─────────────────────────────────────────────────────────────

-- VISTA 1: Resumen de performance de cada Bundle
CREATE VIEW vw_Performance_Bundles AS
SELECT
    b.id_bundle,
    b.nombre                                        AS nombre_bundle,
    b.tipo_vehiculo,
    b.descuento_pct,
    b.lift,
    b.confianza,
    COUNT(v.id_venta)                               AS total_ventas,
    SUM(v.total)                                    AS ingresos_totales,
    SUM(v.descuento_pesos)                          AS descuentos_otorgados,
    AVG(CAST(v.total AS FLOAT))                     AS ticket_promedio,
    -- Clasificacion automatica de rendimiento por lift
    CASE
        WHEN b.lift >= 4.0 THEN 'EXCELENTE'
        WHEN b.lift >= 3.0 THEN 'BUENO'
        WHEN b.lift >= 2.0 THEN 'REGULAR'
        ELSE 'BAJO'
    END                                             AS nivel_asociacion
FROM Bundles b
LEFT JOIN Ventas v ON b.id_bundle = v.id_bundle
GROUP BY b.id_bundle, b.nombre, b.tipo_vehiculo,
         b.descuento_pct, b.lift, b.confianza;
GO

-- VISTA 2: Frecuencia de co-compra real entre productos
-- (minería de datos básica sobre las transacciones reales)
CREATE VIEW vw_Coaparicion_Productos AS
SELECT
    dv1.codigo_producto     AS producto_A,
    p1.nombre               AS nombre_A,
    dv2.codigo_producto     AS producto_B,
    p2.nombre               AS nombre_B,
    COUNT(*)                AS veces_juntos,
    -- Lift aproximado: frecuencia conjunta vs frecuencia individual esperada
    CAST(COUNT(*) AS FLOAT) /
        NULLIF((SELECT COUNT(*) FROM Detalle_Venta dx WHERE dx.codigo_producto = dv1.codigo_producto) *
               (SELECT COUNT(*) FROM Detalle_Venta dy WHERE dy.codigo_producto = dv2.codigo_producto) /
               NULLIF(CAST((SELECT COUNT(DISTINCT id_venta) FROM Detalle_Venta) AS FLOAT), 0), 0)
                            AS lift_calculado
FROM Detalle_Venta dv1
INNER JOIN Detalle_Venta dv2
    ON dv1.id_venta = dv2.id_venta
    AND dv1.codigo_producto < dv2.codigo_producto   -- evita duplicados
INNER JOIN Productos p1 ON dv1.codigo_producto = p1.codigo
INNER JOIN Productos p2 ON dv2.codigo_producto = p2.codigo
GROUP BY dv1.codigo_producto, p1.nombre, dv2.codigo_producto, p2.nombre;
GO

-- VISTA 3: Perfil de cliente con historial de compra
CREATE VIEW vw_Perfil_Cliente AS
SELECT
    c.id_cliente,
    c.nombres + ' ' + c.apellidos              AS nombre_completo,
    c.ciudad,
    c.tipo_vehiculo,
    COUNT(DISTINCT v.id_venta)                  AS total_compras,
    SUM(v.total)                                AS valor_total_comprado,
    AVG(CAST(v.total AS FLOAT))                 AS ticket_promedio,
    MAX(v.fecha_venta)                          AS ultima_compra,
    -- Segmentacion automatica por valor
    CASE
        WHEN SUM(v.total) >= 2000000 THEN 'VIP'
        WHEN SUM(v.total) >= 1000000 THEN 'FRECUENTE'
        WHEN SUM(v.total) >= 500000  THEN 'REGULAR'
        ELSE 'OCASIONAL'
    END                                         AS segmento_cliente,
    COUNT(DISTINCT CASE WHEN v.id_bundle IS NOT NULL THEN v.id_venta END) AS compras_con_bundle
FROM Clientes c
LEFT JOIN Ventas v ON c.id_cliente = v.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos, c.ciudad, c.tipo_vehiculo;
GO

-- VISTA 4: Alertas de inventario bajo
CREATE VIEW vw_Alertas_Inventario AS
SELECT
    i.codigo_producto,
    p.nombre                AS nombre_producto,
    p.categoria,
    p.tipo_vehiculo,
    i.stock_actual,
    i.stock_minimo,
    i.stock_maximo,
    i.stock_actual - i.stock_minimo             AS margen_seguridad,
    CAST(i.stock_actual AS FLOAT) / NULLIF(i.stock_maximo, 0) * 100 AS pct_capacidad,
    CASE
        WHEN i.stock_actual <= i.stock_minimo THEN 'URGENTE - REPONER YA'
        WHEN i.stock_actual <= i.stock_minimo * 1.5 THEN 'ADVERTENCIA - Stock bajo'
        ELSE 'OK'
    END                                         AS estado_stock
FROM Inventario i
INNER JOIN Productos p ON i.codigo_producto = p.codigo;
GO

-- ─────────────────────────────────────────────────────────────
-- CONSULTAS ANALÍTICAS
-- ─────────────────────────────────────────────────────────────

-- CONSULTA 1: Ver todos los bundles con su descuento y fuerza de asociación
-- Lift > 1 = los productos se compran juntos más de lo esperado por azar
SELECT
    id_bundle       AS Codigo_Kit,
    nombre          AS Nombre_Kit,
    tipo_vehiculo   AS Vehiculo,
    descuento_pct   AS [Descuento %],
    lift            AS [Lift (fuerza)],
    confianza       AS [Confianza],
    CASE
        WHEN lift >= 4.0 THEN '★★★ EXCELENTE'
        WHEN lift >= 3.0 THEN '★★  BUENO'
        WHEN lift >= 2.0 THEN '★   REGULAR'
        ELSE '    BAJO'
    END             AS Nivel_Asociacion
FROM Bundles
ORDER BY lift DESC;
GO

-- CONSULTA 2: Cuántas veces se vendió cada kit y cuánto ahorraron los clientes
SELECT
    b.nombre                        AS Nombre_Kit,
    b.tipo_vehiculo                 AS Vehiculo,
    b.lift                          AS Lift,
    b.confianza                     AS Confianza,
    COUNT(v.id_venta)               AS Veces_Vendido,
    SUM(v.total)                    AS Ingresos_Generados,
    SUM(v.descuento_pesos)          AS Total_Ahorrado_Clientes,
    AVG(CAST(v.total AS FLOAT))     AS Ticket_Promedio
FROM Ventas v
INNER JOIN Bundles b ON v.id_bundle = b.id_bundle
GROUP BY b.id_bundle, b.nombre, b.tipo_vehiculo, b.lift, b.confianza
ORDER BY Veces_Vendido DESC;
GO

-- CONSULTA 3: Motor de recomendación — Top 10 pares de productos
-- más frecuentemente comprados juntos (análisis de canasta real)
SELECT TOP 10
    producto_A,
    nombre_A,
    producto_B,
    nombre_B,
    veces_juntos        AS Frecuencia_CoCompra,
    ROUND(lift_calculado, 3) AS Lift_Real
FROM vw_Coaparicion_Productos
ORDER BY veces_juntos DESC;
GO

-- CONSULTA 4: Segmentación de clientes con métricas RFM simplificado
-- (Recencia, Frecuencia, Valor Monetario)
SELECT TOP 20
    nombre_completo,
    ciudad,
    tipo_vehiculo,
    total_compras           AS Frecuencia,
    valor_total_comprado    AS Valor_Monetario,
    ticket_promedio         AS Ticket_Promedio,
    ultima_compra           AS Ultima_Compra,
    segmento_cliente        AS Segmento,
    compras_con_bundle      AS Compras_Con_Bundle
FROM vw_Perfil_Cliente
ORDER BY valor_total_comprado DESC;
GO

-- CONSULTA 5: Predicción de canal más exitoso por tipo de vehículo
-- (lógica de decisión: dónde concentrar esfuerzos de venta)
SELECT
    c.tipo_vehiculo,
    v.canal,
    COUNT(v.id_venta)                       AS Total_Ventas,
    SUM(v.total)                            AS Ingresos,
    AVG(CAST(v.total AS FLOAT))             AS Ticket_Promedio,
    SUM(CASE WHEN v.id_bundle IS NOT NULL THEN 1 ELSE 0 END) AS Ventas_Con_Bundle,
    CAST(SUM(CASE WHEN v.id_bundle IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(v.id_venta), 0) * 100  AS Pct_Adopcion_Bundle
FROM Ventas v
INNER JOIN Clientes c ON v.id_cliente = c.id_cliente
GROUP BY c.tipo_vehiculo, v.canal
ORDER BY c.tipo_vehiculo, Ingresos DESC;
GO

-- CONSULTA 6: Análisis automático de bundles — ¿Cuál bundle recomendar
-- a un cliente según su tipo de vehículo y presupuesto?
-- (lógica de decisión basada en datos)
SELECT
    b.tipo_vehiculo,
    b.id_bundle,
    b.nombre                                AS Bundle_Recomendado,
    b.lift,
    b.confianza,
    b.descuento_pct,
    -- Precio estimado del bundle (suma de precios de productos)
    SUM(p.precio_venta)                     AS Precio_Base_Bundle,
    ROUND(SUM(p.precio_venta) * (1 - b.descuento_pct / 100.0), 0) AS Precio_Con_Descuento,
    -- Score compuesto de recomendación (lift * confianza * adopción)
    ROUND(b.lift * b.confianza, 4)          AS Score_Recomendacion
FROM Bundles b
INNER JOIN Detalle_Bundle db ON b.id_bundle = db.id_bundle
INNER JOIN Productos p ON db.codigo_producto = p.codigo
WHERE b.activo = 1
GROUP BY b.id_bundle, b.nombre, b.tipo_vehiculo, b.lift, b.confianza, b.descuento_pct
ORDER BY b.tipo_vehiculo, Score_Recomendacion DESC;
GO

-- CONSULTA 7: Productos más vendidos con margen de ganancia
-- (métrica inteligente de rentabilidad por producto)
SELECT
    p.codigo,
    p.nombre,
    p.categoria,
    p.tipo_vehiculo,
    p.precio_costo,
    p.precio_venta,
    p.precio_venta - p.precio_costo                     AS Margen_Pesos,
    ROUND(CAST(p.precio_venta - p.precio_costo AS FLOAT) /
          NULLIF(p.precio_costo, 0) * 100, 1)           AS Margen_Pct,
    COUNT(dv.id_detalle)                                AS Unidades_Vendidas,
    SUM(dv.subtotal_linea)                              AS Ingresos_Producto,
    SUM(dv.subtotal_linea) -
        COUNT(dv.id_detalle) * p.precio_costo          AS Utilidad_Bruta
FROM Productos p
LEFT JOIN Detalle_Venta dv ON p.codigo = dv.codigo_producto
WHERE p.activo = 1
GROUP BY p.codigo, p.nombre, p.categoria, p.tipo_vehiculo,
         p.precio_costo, p.precio_venta
ORDER BY Unidades_Vendidas DESC;
GO

-- CONSULTA 8: Tendencia de ventas mensual (análisis temporal)
SELECT
    YEAR(fecha_venta)   AS Anio,
    MONTH(fecha_venta)  AS Mes,
    COUNT(id_venta)     AS Total_Ventas,
    SUM(total)          AS Ingresos_Mes,
    SUM(descuento_pesos) AS Descuentos_Mes,
    SUM(CASE WHEN id_bundle IS NOT NULL THEN 1 ELSE 0 END) AS Ventas_Bundle,
    ROUND(
        CAST(SUM(CASE WHEN id_bundle IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) /
        NULLIF(COUNT(id_venta), 0) * 100, 1
    )                   AS Pct_Ventas_Con_Bundle
FROM Ventas
GROUP BY YEAR(fecha_venta), MONTH(fecha_venta)
ORDER BY Anio, Mes;
GO

-- CONSULTA 9: Alertas automáticas de inventario crítico
-- (lógica de decisión basada en datos — qué reponer hoy)
SELECT
    codigo_producto,
    nombre_producto,
    categoria,
    tipo_vehiculo,
    stock_actual,
    stock_minimo,
    margen_seguridad,
    ROUND(pct_capacidad, 1) AS [Capacidad Usada %],
    estado_stock
FROM vw_Alertas_Inventario
WHERE estado_stock != 'OK'
ORDER BY
    CASE estado_stock
        WHEN 'URGENTE - REPONER YA' THEN 1
        WHEN 'ADVERTENCIA - Stock bajo' THEN 2
        ELSE 3
    END,
    margen_seguridad ASC;
GO

-- CONSULTA 10: Qué productos tiene cada bundle y su valor total
SELECT
    b.id_bundle,
    b.nombre            AS Nombre_Bundle,
    b.tipo_vehiculo,
    b.lift,
    b.confianza,
    p.codigo,
    p.nombre            AS Nombre_Producto,
    p.categoria,
    p.precio_venta
FROM Bundles b
INNER JOIN Detalle_Bundle db ON b.id_bundle = db.id_bundle
INNER JOIN Productos p ON db.codigo_producto = p.codigo
ORDER BY b.id_bundle, p.categoria;
GO

-- CONSULTA 11: Reporte ejecutivo — KPIs del negocio
SELECT
    'TOTAL VENTAS'                          AS Indicador,
    CAST(COUNT(*) AS VARCHAR)              AS Valor
FROM Ventas
UNION ALL
SELECT 'INGRESOS TOTALES', FORMAT(SUM(total), 'N0', 'es-CO')
FROM Ventas
UNION ALL
SELECT 'DESCUENTOS OTORGADOS', FORMAT(SUM(descuento_pesos), 'N0', 'es-CO')
FROM Ventas
UNION ALL
SELECT 'CLIENTES ACTIVOS', CAST(COUNT(DISTINCT id_cliente) AS VARCHAR)
FROM Ventas
UNION ALL
SELECT 'VENTAS CON BUNDLE (%)',
    CAST(ROUND(
        CAST(COUNT(CASE WHEN id_bundle IS NOT NULL THEN 1 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100, 1
    ) AS VARCHAR) + '%'
FROM Ventas
UNION ALL
SELECT 'TICKET PROMEDIO', FORMAT(AVG(CAST(total AS FLOAT)), 'N0', 'es-CO')
FROM Ventas
UNION ALL
SELECT 'BUNDLE MAS VENDIDO',
    (SELECT TOP 1 b.nombre FROM Bundles b
     INNER JOIN Ventas v2 ON b.id_bundle = v2.id_bundle
     GROUP BY b.nombre ORDER BY COUNT(*) DESC)
FROM (SELECT 1 AS x) t
UNION ALL
SELECT 'PRODUCTO ESTRELLA',
    (SELECT TOP 1 p.nombre FROM Productos p
     INNER JOIN Detalle_Venta dv ON p.codigo = dv.codigo_producto
     GROUP BY p.nombre ORDER BY COUNT(*) DESC)
FROM (SELECT 1 AS x) t;
GO
