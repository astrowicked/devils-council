import * as Sentry from '@sentry/node';
import mixpanel from 'mixpanel-browser';

Sentry.init({
  dsn: 'https://abcd1234@o12345.ingest.sentry.io/67890',
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
});

mixpanel.init('00000000000000000000000000000000');

export function track(event: string, props: Record<string, unknown>): void {
  mixpanel.track(event, props);
}
