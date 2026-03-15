export interface RegisterRequest {
  platform: "ios" | "android"
  pushToken: string
  intervalSeconds?: number
  ttlSeconds?: number
}

export interface Env {
  PUSH_REGISTRATION: DurableObjectNamespace
  RATE_LIMITER: DurableObjectNamespace
  APNS_TEAM_ID: string
  APNS_KEY_ID: string
  APNS_PRIVATE_KEY: string
  APNS_ENVIRONMENT: string
  FCM_PROJECT_ID: string
  FCM_CLIENT_EMAIL: string
  FCM_PRIVATE_KEY: string
}
