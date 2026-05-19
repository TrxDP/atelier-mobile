import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private client!: Redis;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('REDIS_HOST', 'localhost');
    const port = this.configService.get<number>('REDIS_PORT', 6379);

    this.client = new Redis({
      host,
      port,
      maxRetriesPerRequest: null, // Requerido para integraciones de colas como BullMQ
    });
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.disconnect();
    }
  }

  /**
   * Obtiene el cliente nativo de ioredis.
   */
  getClient(): Redis {
    return this.client;
  }

  /**
   * Obtiene una clave de caché.
   */
  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  /**
   * Guarda un valor en caché con un tiempo de expiración opcional (TTL en segundos).
   */
  async set(key: string, value: string, ttlSeconds?: number): Promise<'OK' | string> {
    if (ttlSeconds) {
      return this.client.set(key, value, 'EX', ttlSeconds);
    }
    return this.client.set(key, value);
  }

  /**
   * Elimina una clave de caché.
   */
  async del(key: string): Promise<number> {
    return this.client.del(key);
  }
}
