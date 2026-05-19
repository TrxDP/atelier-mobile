import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Prefijo global para todos los endpoints
  app.setGlobalPrefix('api');

  // Habilitar CORS para peticiones desde emuladores o dispositivos físicos
  app.enableCors({
    origin: '*', // En producción se debe restringir a dominios específicos
    credentials: true,
  });

  // Habilitar validaciones globales con class-validator
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // Elimina propiedades no definidas en los DTOs
      transform: true, // Transforma tipos de datos a los declarados en los DTOs
      forbidNonWhitelisted: true, // Lanza error si se envían propiedades no permitidas
    }),
  );

  // Configuración de Documentación Swagger
  const config = new DocumentBuilder()
    .setTitle('Atelier Pro API')
    .setDescription(
      'Documentación de la API REST para la gestión de microempresas adaptables (Lavanderías, Alquileres, Caja, Activos).',
    )
    .setVersion('1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'JWT',
        description: 'Introduce tu token JWT de acceso',
        in: 'header',
      },
      'JWT-auth', // Nombre de la clave de autenticación en Swagger
    )
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`🚀 Servidor ejecutándose en: http://localhost:${port}/api`);
  console.log(`📚 Documentación Swagger en: http://localhost:${port}/api/docs`);
}
bootstrap();

