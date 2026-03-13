-- S.F.C.P.C - Initial Database Schema
-- Multi-tenancy Model: tenant_id per record

-- 1. Tenants Table
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL, -- Logical identifier (e.g., 'company-a')
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Locations Table
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, name)
);

-- 3. Products Table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code TEXT NOT NULL, -- SKU / Internal code
    description TEXT NOT NULL,
    unit TEXT NOT NULL, -- UN, KG, LT, etc.
    min_stock DECIMAL(12, 2) DEFAULT 0,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, code)
);

-- 4. Batches Table (For validity and batch tracking)
CREATE TABLE IF NOT EXISTS product_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_number TEXT NOT NULL,
    validity_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, product_id, batch_number)
);

-- 5. Stock Balance Table (Real-time balance)
CREATE TABLE IF NOT EXISTS stock_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES product_batches(id),
    location_id UUID REFERENCES locations(id),
    balance DECIMAL(12, 2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, product_id, batch_id, location_id)
);

-- 6. Movements Table (Audit trail)
CREATE TABLE IF NOT EXISTS movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES product_batches(id),
    location_id UUID REFERENCES locations(id),
    type TEXT NOT NULL CHECK (type IN ('ENTRY', 'EXIT', 'TRANSFER', 'ADJUSTMENT')),
    quantity DECIMAL(12, 2) NOT NULL,
    user_id UUID, -- To be linked with Auth service later
    reference_doc TEXT, -- Invoice number / Order number
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indices for performance and multi-tenancy isolation
CREATE INDEX idx_products_tenant ON products(tenant_id);
CREATE INDEX idx_movements_tenant ON movements(tenant_id);
CREATE INDEX idx_stock_balances_tenant ON stock_balances(tenant_id);
