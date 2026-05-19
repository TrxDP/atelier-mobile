import 'dotenv/config';
import { PrismaClient, Role, AssetStatus, TransactionStatus, PaymentMethod } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Iniciando la siembra de base de datos...');

  // 1. Limpiar base de datos (con cuidado del orden por dependencias relacionales)
  await prisma.payment.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.asset.deleteMany();
  await prisma.user.deleteMany();
  await prisma.business.deleteMany();
  console.log('🧹 Base de datos limpia de registros anteriores.');

  // 2. Definir e insertar el esquema dinámico de Lavandería
  const schemaConfig = [
    { name: 'lavadora_asignada', type: 'text', label: 'Lavadora Asignada', required: true },
    { name: 'tiempo_estimado', type: 'number', label: 'Tiempo Estimado (minutos)', required: true },
    { name: 'hora_inicio', type: 'datetime', label: 'Hora de Inicio', required: true },
    { name: 'estado_pago', type: 'select', label: 'Estado de Pago', options: ['PENDIENTE', 'PAGADO'], required: true }
  ];

  const business = await prisma.business.create({
    data: {
      name: 'Atelier Lavandería Pro',
      // Guardamos la estructura del esquema como objeto JSON nativo
      schemaConfig: schemaConfig,
    },
  });
  console.log(`🏢 Negocio de Lavandería creado: ${business.name} (${business.id})`);

  // 3. Crear usuarios del negocio
  const hashedPassword = await bcrypt.hash('AtelierPro2026!', 10);
  
  const owner = await prisma.user.create({
    data: {
      email: 'owner@atelier.pro',
      password: hashedPassword,
      role: Role.OWNER,
      businessId: business.id,
    },
  });
  console.log(`👤 Usuario Dueño (OWNER) creado: ${owner.email}`);

  const employee = await prisma.user.create({
    data: {
      email: 'empleado@atelier.pro',
      password: hashedPassword,
      role: Role.EMPLOYEE,
      businessId: business.id,
    },
  });
  console.log(`👤 Usuario Empleado (EMPLOYEE) creado: ${employee.email}`);

  // 4. Crear algunos Activos (Lavadoras y secadoras)
  const assetsData = [
    { name: 'Lavadora LG Turbowash 20kg', type: 'WASHER', status: AssetStatus.ACTIVE },
    { name: 'Lavadora Whirlpool Heavy Duty 18kg', type: 'WASHER', status: AssetStatus.ACTIVE },
    { name: 'Secadora Samsung Heat Pump 15kg', type: 'DRYER', status: AssetStatus.ACTIVE },
    { name: 'Lavadora LG Turbowash 15kg (Falla de Motor)', type: 'WASHER', status: AssetStatus.MAINTENANCE },
  ];

  for (const asset of assetsData) {
    const createdAsset = await prisma.asset.create({
      data: {
        name: asset.name,
        type: asset.type,
        status: asset.status,
        businessId: business.id,
        metadata: {
          modelo: '2025-V1',
          marca: asset.name.includes('LG') ? 'LG' : asset.name.includes('Samsung') ? 'Samsung' : 'Whirlpool',
        }
      },
    });
    console.log(`🛠️ Activo creado: ${createdAsset.name}`);
  }

  // 5. Crear algunas transacciones de ejemplo con metadatos dinámicos
  const transaction1 = await prisma.transaction.create({
    data: {
      businessId: business.id,
      status: TransactionStatus.IN_PROGRESS,
      totalAmount: 15.50,
      metadata: {
        lavadora_asignada: 'Lavadora LG Turbowash 20kg',
        tiempo_estimado: 45,
        hora_inicio: new Date().toISOString(),
        estado_pago: 'PENDIENTE',
      },
    },
  });

  const transaction2 = await prisma.transaction.create({
    data: {
      businessId: business.id,
      status: TransactionStatus.COMPLETED,
      totalAmount: 25.00,
      metadata: {
        lavadora_asignada: 'Lavadora Whirlpool Heavy Duty 18kg',
        tiempo_estimado: 60,
        hora_inicio: new Date(Date.now() - 3600000 * 2).toISOString(), // hace 2 horas
        estado_pago: 'PAGADO',
      },
    },
  });
  console.log('📝 Transacciones de prueba (lavados registrados) creadas.');

  // 6. Crear un pago para la transacción completada y pagada
  await prisma.payment.create({
    data: {
      transactionId: transaction2.id,
      businessId: business.id,
      amount: 25.00,
      paymentMethod: PaymentMethod.CASH,
    },
  });
  console.log('💵 Pago registrado en caja.');

  console.log('🌱 Siembra de base de datos completada con éxito.');
}

main()
  .catch((e) => {
    console.error('❌ Error en el proceso de siembra:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
