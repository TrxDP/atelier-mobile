-- ══════════════════════════════════════════════════════════════
--  Atelier Pro — Esquema principal
--  Archivo : 01_schema.sql
--  Motor   : PostgreSQL 16
-- ══════════════════════════════════════════════════════════════

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ──────────────────────────────────────────────────────────────
--  TIPOS ENUMERADOS
-- ──────────────────────────────────────────────────────────────

CREATE TYPE business_type_enum AS ENUM (
    'rental',       -- solo alquiler
    'sales',        -- solo venta
    'mixed'         -- alquiler + venta
);

CREATE TYPE user_role_enum AS ENUM (
    'owner',        -- dueño: acceso total
    'manager',      -- gerente: todo menos ajustes de cuenta
    'cashier',      -- cajero: transacciones y pagos
    'technician'    -- técnico: solo mantenimiento
);

CREATE TYPE time_unit_enum AS ENUM (
    'hour',
    'day',
    'week',
    'month'
);

CREATE TYPE asset_status_enum AS ENUM (
    'available',        -- libre para alquilar
    'in_use',           -- alquilado actualmente
    'maintenance',      -- en mantenimiento programado
    'damaged',          -- dañado, fuera de servicio
    'retired'           -- dado de baja
);

CREATE TYPE transaction_type_enum AS ENUM (
    'rental',
    'sale'
);

CREATE TYPE transaction_status_enum AS ENUM (
    'active',           -- alquiler en curso
    'completed',        -- finalizado y pagado
    'pending_payment',  -- finalizado pero con saldo pendiente
    'cancelled'         -- cancelado
);

CREATE TYPE payment_method_enum AS ENUM (
    'cash',
    'transfer',
    'card',
    'other'
);

CREATE TYPE maintenance_type_enum AS ENUM (
    'preventive',   -- mantenimiento programado
    'corrective',   -- reparación por daño
    'inspection'    -- revisión sin intervención
);

CREATE TYPE maintenance_status_enum AS ENUM (
    'scheduled',    -- programado
    'in_progress',  -- en proceso
    'completed',    -- completado
    'cancelled'     -- cancelado
);

-- ──────────────────────────────────────────────────────────────
--  1. NEGOCIOS (businesses)
--     Cada fila = una microempresa. Multitenancy a nivel de BD.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE businesses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(120)         NOT NULL,
    business_type   business_type_enum   NOT NULL DEFAULT 'rental',
    slug            VARCHAR(80)          UNIQUE NOT NULL,
    phone           VARCHAR(30),
    email           VARCHAR(120),
    address         TEXT,
    city            VARCHAR(80),
    country         CHAR(2)              DEFAULT 'CO',
    logo_url        TEXT,
    is_active       BOOLEAN              NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE businesses IS
    'Cada registro es una microempresa cliente de Atelier Pro.';

-- ──────────────────────────────────────────────────────────────
--  2. USUARIOS (users)
--     Empleados y dueños del negocio.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID                 NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name       VARCHAR(120)         NOT NULL,
    email           VARCHAR(120)         NOT NULL,
    password_hash   TEXT                 NOT NULL,
    role            user_role_enum       NOT NULL DEFAULT 'cashier',
    phone           VARCHAR(30),
    avatar_url      TEXT,
    is_active       BOOLEAN              NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ          NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_email_per_business UNIQUE (business_id, email)
);

COMMENT ON TABLE users IS
    'Usuarios con acceso al sistema. Cada usuario pertenece a un negocio.';

-- ──────────────────────────────────────────────────────────────
--  3. CONFIGURACIÓN DEL NEGOCIO (business_config)
--     1-a-1 con businesses. Guarda preferencias y módulos.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE business_config (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id             UUID             NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    default_time_unit       time_unit_enum   NOT NULL DEFAULT 'day',
    deposit_enabled         BOOLEAN          NOT NULL DEFAULT FALSE,
    default_deposit_amount  DECIMAL(10,2)    NOT NULL DEFAULT 0,
    maintenance_alerts      BOOLEAN          NOT NULL DEFAULT TRUE,
    maintenance_alert_days  INTEGER          NOT NULL DEFAULT 7,
    sale_mode_enabled       BOOLEAN          NOT NULL DEFAULT FALSE,
    currency_code           CHAR(3)          NOT NULL DEFAULT 'COP',
    currency_symbol         VARCHAR(5)       NOT NULL DEFAULT '$',
    -- Campos personalizados definidos por el negocio (clave-tipo)
    -- Ejemplo: {"placa": "text", "kilometraje": "number", "capacidad_kg": "number"}
    custom_field_schema     JSONB            NOT NULL DEFAULT '{}',
    updated_at              TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_config_per_business UNIQUE (business_id)
);

COMMENT ON COLUMN business_config.custom_field_schema IS
    'JSON que define los campos extra por tipo de activo. Permite adaptabilidad sin cambiar el esquema.';

-- ──────────────────────────────────────────────────────────────
--  4. CATEGORÍAS DE ACTIVOS (asset_categories)
--     Agrupación visual de activos (motos, lavadoras, herramientas…)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE asset_categories (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID             NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name            VARCHAR(80)      NOT NULL,
    icon            VARCHAR(60),     -- nombre del ícono (ti-motorcycle, ti-washing-machine…)
    description     TEXT,
    sort_order      SMALLINT         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_category_name_per_business UNIQUE (business_id, name)
);

-- ──────────────────────────────────────────────────────────────
--  5. ACTIVOS (assets)
--     Cada máquina, moto, herramienta o puesto de venta.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE assets (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id         UUID               NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id         UUID               REFERENCES asset_categories(id) ON DELETE SET NULL,
    name                VARCHAR(120)       NOT NULL,
    sku                 VARCHAR(60),
    description         TEXT,
    status              asset_status_enum  NOT NULL DEFAULT 'available',
    -- Tarifas de alquiler (null si el activo es solo para venta)
    rate_hour           DECIMAL(10,2),
    rate_day            DECIMAL(10,2),
    rate_week           DECIMAL(10,2),
    rate_month          DECIMAL(10,2),
    -- Datos de inventario (para venta)
    stock_quantity      INTEGER            NOT NULL DEFAULT 0,
    stock_min_alert     INTEGER            NOT NULL DEFAULT 0,
    unit_cost           DECIMAL(10,2),     -- costo de venta al público
    -- Datos de adquisición
    acquisition_cost    DECIMAL(10,2),     -- cuánto costó comprar el activo
    acquired_at         DATE,
    serial_number       VARCHAR(80),
    -- Campos personalizados del negocio (coincide con custom_field_schema)
    -- Ejemplo: {"placa": "ABC-123", "kilometraje": 45000, "capacidad_kg": 9}
    custom_attributes   JSONB              NOT NULL DEFAULT '{}',
    notes               TEXT,
    image_url           TEXT,
    is_active           BOOLEAN            NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ        NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_sku_per_business UNIQUE (business_id, sku)
);

COMMENT ON TABLE assets IS
    'Activos físicos del negocio: máquinas de alquiler, motos, herramientas o productos de venta.';
COMMENT ON COLUMN assets.custom_attributes IS
    'Valores de los campos personalizados definidos en business_config.custom_field_schema.';

-- ──────────────────────────────────────────────────────────────
--  6. CLIENTES (clients)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE clients (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id         UUID         NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name           VARCHAR(120) NOT NULL,
    phone               VARCHAR(30),
    email               VARCHAR(120),
    id_number           VARCHAR(30),   -- cédula / pasaporte
    license_number      VARCHAR(30),   -- licencia de conducción (motos)
    address             TEXT,
    notes               TEXT,
    -- Balance calculado automáticamente por trigger/app
    outstanding_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────
--  7. TRANSACCIONES (transactions)
--     Alquileres y ventas. Núcleo del negocio.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID                     NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    asset_id        UUID                     NOT NULL REFERENCES assets(id),
    client_id       UUID                     NOT NULL REFERENCES clients(id),
    created_by      UUID                     NOT NULL REFERENCES users(id),
    -- Tipo y estado
    type            transaction_type_enum    NOT NULL DEFAULT 'rental',
    status          transaction_status_enum  NOT NULL DEFAULT 'active',
    -- Alquiler: período y tarifa
    time_unit       time_unit_enum,
    start_at        TIMESTAMPTZ,
    end_at          TIMESTAMPTZ,
    rate_applied    DECIMAL(10,2),           -- tarifa que se usó al crear (snapshot)
    -- Montos
    subtotal        DECIMAL(10,2)            NOT NULL DEFAULT 0,
    deposit_amount  DECIMAL(10,2)            NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10,2)            NOT NULL DEFAULT 0,
    total_amount    DECIMAL(10,2)            NOT NULL DEFAULT 0,
    amount_paid     DECIMAL(10,2)            NOT NULL DEFAULT 0,
    balance_due     DECIMAL(10,2)            NOT NULL DEFAULT 0,
    -- Referencia y notas
    reference_code  VARCHAR(30)              UNIQUE,
    notes           TEXT,
    cancelled_at    TIMESTAMPTZ,
    cancelled_by    UUID                     REFERENCES users(id),
    cancel_reason   TEXT,
    created_at      TIMESTAMPTZ              NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ              NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_rental_has_dates CHECK (
        type != 'rental' OR (start_at IS NOT NULL AND end_at IS NOT NULL)
    ),
    CONSTRAINT chk_end_after_start CHECK (
        end_at IS NULL OR end_at > start_at
    ),
    CONSTRAINT chk_amounts_positive CHECK (
        total_amount >= 0 AND amount_paid >= 0 AND balance_due >= 0
    )
);

COMMENT ON TABLE transactions IS
    'Registro de cada alquiler o venta. El campo reference_code es el número legible para el cliente.';

-- ──────────────────────────────────────────────────────────────
--  8. ÍTEMS DE VENTA (sale_items)
--     Detalle de productos en una transacción de tipo sale.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE sale_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID          NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    asset_id        UUID          NOT NULL REFERENCES assets(id),
    quantity        INTEGER       NOT NULL DEFAULT 1,
    unit_price      DECIMAL(10,2) NOT NULL,
    discount        DECIMAL(10,2) NOT NULL DEFAULT 0,
    subtotal        DECIMAL(10,2) NOT NULL,

    CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_price_positive    CHECK (unit_price >= 0)
);

-- ──────────────────────────────────────────────────────────────
--  9. PAGOS (payments)
--     Cada abono a una transacción.
-- ──────────────────────────────────────────────────────────────

CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID                 NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    registered_by   UUID                 NOT NULL REFERENCES users(id),
    amount          DECIMAL(10,2)        NOT NULL,
    method          payment_method_enum  NOT NULL DEFAULT 'cash',
    reference       VARCHAR(80),         -- número de transferencia, etc.
    notes           TEXT,
    paid_at         TIMESTAMPTZ          NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_payment_positive CHECK (amount > 0)
);

COMMENT ON TABLE payments IS
    'Cada fila es un abono. Una transacción puede tener N pagos parciales.';

-- ──────────────────────────────────────────────────────────────
--  10. MANTENIMIENTO (maintenance_records)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE maintenance_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id        UUID                     NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    registered_by   UUID                     NOT NULL REFERENCES users(id),
    type            maintenance_type_enum    NOT NULL DEFAULT 'corrective',
    status          maintenance_status_enum  NOT NULL DEFAULT 'scheduled',
    description     TEXT                     NOT NULL,
    cost            DECIMAL(10,2)            NOT NULL DEFAULT 0,
    provider_name   VARCHAR(120),            -- taller o técnico externo
    scheduled_date  DATE,
    completed_date  DATE,
    notes           TEXT,
    created_at      TIMESTAMPTZ              NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ              NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────
--  11. GASTOS OPERATIVOS (expenses)
--     Costos del negocio que no son mantenimiento de un activo.
--     (insumos, alquiler del local, servicios…)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE expenses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID          NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    registered_by   UUID          NOT NULL REFERENCES users(id),
    category        VARCHAR(80)   NOT NULL,   -- 'insumos', 'servicios', 'local', etc.
    description     TEXT          NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    expense_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
    receipt_url     TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_expense_positive CHECK (amount > 0)
);

-- ──────────────────────────────────────────────────────────────
--  FUNCIÓN: auto-actualizar updated_at
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Triggers updated_at
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'businesses','users','assets','clients',
        'transactions','maintenance_records','business_config'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%s_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
            t, t
        );
    END LOOP;
END;
$$;

-- ──────────────────────────────────────────────────────────────
--  FUNCIÓN + TRIGGER: generar reference_code único
--  Formato: TRX-YYYYMMDD-NNNN  (ej: TRX-20241024-0041)
-- ──────────────────────────────────────────────────────────────

CREATE SEQUENCE IF NOT EXISTS transaction_seq START 1;

CREATE OR REPLACE FUNCTION generate_reference_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.reference_code IS NULL THEN
        NEW.reference_code := 'TRX-'
            || TO_CHAR(NOW(), 'YYYYMMDD') || '-'
            || LPAD(nextval('transaction_seq')::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transactions_reference
    BEFORE INSERT ON transactions
    FOR EACH ROW EXECUTE FUNCTION generate_reference_code();

-- ──────────────────────────────────────────────────────────────
--  FUNCIÓN + TRIGGER: actualizar balance_due del cliente
--  cuando cambia amount_paid en transactions
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_client_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE clients
    SET outstanding_balance = (
        SELECT COALESCE(SUM(balance_due), 0)
        FROM transactions
        WHERE client_id = NEW.client_id
          AND status = 'pending_payment'
    )
    WHERE id = NEW.client_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_balance_after_transaction
    AFTER INSERT OR UPDATE OF balance_due, status ON transactions
    FOR EACH ROW EXECUTE FUNCTION sync_client_balance();

-- ──────────────────────────────────────────────────────────────
--  FUNCIÓN + TRIGGER: actualizar estado del activo
--  según el estado de sus transacciones activas
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_asset_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Si hay una transacción activa → activo en uso
    IF NEW.status = 'active' AND NEW.type = 'rental' THEN
        UPDATE assets SET status = 'in_use' WHERE id = NEW.asset_id;
    -- Si la transacción se completó o canceló → volver a disponible
    ELSIF NEW.status IN ('completed', 'cancelled', 'pending_payment') THEN
        -- Solo si no hay otra transacción activa sobre el mismo activo
        IF NOT EXISTS (
            SELECT 1 FROM transactions
            WHERE asset_id = NEW.asset_id
              AND status = 'active'
              AND id != NEW.id
        ) THEN
            UPDATE assets
            SET status = 'available'
            WHERE id = NEW.asset_id
              AND status = 'in_use';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_asset_status
    AFTER INSERT OR UPDATE OF status ON transactions
    FOR EACH ROW EXECUTE FUNCTION sync_asset_status();
