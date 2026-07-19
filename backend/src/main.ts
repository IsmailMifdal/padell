import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as Sentry from '@sentry/node';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  // Crash reporting (actif seulement si SENTRY_DSN est défini)
  if (process.env.SENTRY_DSN) {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.NODE_ENV ?? 'development',
      tracesSampleRate: 0.1,
    });
    console.log('Sentry initialisé');
  }

  const app = await NestFactory.create(AppModule);

  // CSP désactivée pour laisser l'UI Swagger (/docs) charger ses scripts
  app.use(helmet({ contentSecurityPolicy: false }));
  app.enableCors({ origin: true, credentials: true });
  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Documentation OpenAPI interactive sur /docs (JSON : /docs-json)
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Padel API')
    .setDescription(
      'Réservation de terrains & matching de joueurs de padel (Maroc). ' +
        'Authentification : Bearer JWT via POST /v1/auth/login.',
    )
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup(
    'docs',
    app,
    SwaggerModule.createDocument(app, swaggerConfig),
  );

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`🎾 Padel API démarrée sur http://localhost:${port}/v1`);
}
bootstrap();
