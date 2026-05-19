# Atelier Pro - Digitalización Adaptable para Microempresas

Atelier Pro es una solución tecnológica diseñada para digitalizar la gestión de microempresas en Latinoamérica sin necesidad de conocimientos técnicos o suscripciones costosas en divisas extranjeras. Nacido de la necesidad de reemplazar registros informales en cuadernos físicos, Atelier Pro permite a los propietarios configurar de manera dinámica y sin código flujos de:

- 🧺 **Lavanderías** (registro de cliente, lavadora asignada, tiempo estimado, pagos y estado).
- 🏍️ **Alquileres** (vehículos, motos, herramientas, maquinaria).
- 📦 **Ventas y Control Financiero** (gestión de stock, pagos parciales, caja diaria).
- 🛠️ **Mantenimiento de Activos** (seguimiento de maquinaria, lavadoras, vehículos).

---

## 🛠️ Stack Tecnológico

El proyecto está organizado en una estructura monorepo limpia, optimizando la agilidad de desarrollo y permitiendo la compartición conceptual:

1. **Frontend Móvil (`/mobile`)**:
   - **Framework**: React Native con **Expo Bare Workflow** (TypeScript).
   - **Estado y Caché Remota**: React Query (`@tanstack/react-query`) + Axios.
   - **Base de Datos Local (Offline-First)**: **WatermelonDB** con motor SQLite nativo en segundo plano para respuesta inmediata.
   - **Notificaciones**: Expo Push Notifications API.

2. **Backend (`/backend`)**:
   - **Framework**: **NestJS** (TypeScript) con arquitectura modular.
   - **Base de Datos (ORM)**: **PostgreSQL** administrado mediante **Prisma ORM**.
   - **Flexibilidad Dinámica**: Columnas **JSONB** en Postgres para almacenar atributos y esquemas dinámicos por tipo de negocio.
   - **Caché y Mensajería**: **Redis** para control de colas asíncronas y caché de configuraciones de negocio.
   - **Seguridad**: Autenticación JWT con flujo seguro de Refresh Tokens y control de accesos basado en Roles (`owner`, `employee`).

3. **CI/CD e Infraestructura**:
   - **Dockerización**: Docker y Docker Compose para levantar bases de datos y caché localmente.
   - **CI/CD**: Flujos de automatización con **GitHub Actions** para chequeo del móvil y despliegue del backend.
   - **Hosting**: Despliegue automatizado del backend y servicios en **Railway**.

---

## 📂 Estructura del Proyecto

```
atelier/
├── .github/workflows/          # CI/CD (GitHub Actions)
├── backend/                    # Servidor REST en NestJS
│   ├── src/
│   │   ├── common/             # Excepciones, Guards, Interceptors globales
│   │   ├── config/             # Configuración de entornos y base de datos
│   │   └── modules/            # Módulos de dominio (Auth, Users, Businesses, Transactions, etc.)
│   └── prisma/                 # Esquemas y migraciones de base de datos
├── mobile/                     # Aplicación móvil en React Native (Expo)
│   ├── src/
│   │   ├── api/                # Cliente Axios y hooks de React Query
│   │   ├── database/           # Modelos y esquemas de WatermelonDB
│   │   ├── components/         # Componentes UI premium
│   │   └── screens/            # Pantallas de la aplicación
└── docker-compose.yml          # Postgres y Redis para desarrollo local
```

---

## 🚀 Inicio Rápido (Desarrollo Local)

### Requisitos Previos

- [Node.js](https://nodejs.org/) (Versión 18 o superior recomendada)
- [Docker](https://www.docker.com/) y Docker Compose
- [Expo Go] o emulador de Android/iOS (para probar la aplicación móvil)

### Paso 1: Levantar Servicios Locales

En la raíz del proyecto, levanta las instancias de PostgreSQL y Redis:

```bash
docker-compose up -d
```

### Paso 2: Configurar e Iniciar el Backend

1. Navega al directorio `/backend`:
   ```bash
   cd backend
   ```
2. Instala las dependencias y corre las migraciones de Prisma:
   ```bash
   npm install
   npx prisma migrate dev
   ```
3. Inicia el servidor de desarrollo:
   ```bash
   npm run start:dev
   ```
   *La API estará disponible en `http://localhost:3000` con documentación Swagger en `http://localhost:3000/api/docs`.*

### Paso 3: Configurar e Iniciar la App Móvil

1. Navega al directorio `/mobile`:
   ```bash
   cd ../mobile
   ```
2. Instala las dependencias:
   ```bash
   npm install
   ```
3. Inicia el servidor de desarrollo de Expo:
   ```bash
   npx expo start
   ```

---

## 🛡️ Contribuciones y Buenas Prácticas

- Mantén las transacciones críticas de negocio envueltas en **transacciones atómicas** usando Prisma para evitar estados inconsistentes.
- Toda transacción local en la aplicación móvil debe registrarse inmediatamente en **WatermelonDB** para garantizar la velocidad offline, delegando la sincronización al motor de sincronización bidireccional en segundo plano.
- Sigue el principio de diseño premium: interfaces limpias, colores HSL seleccionados y micro-animaciones fluidas en la interfaz del usuario.
