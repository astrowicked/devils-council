import axios from 'axios';

export async function ping(): Promise<void> {
  await fetch('https://api.example.com/ping');
}

export async function reportError(payload: object): Promise<void> {
  await axios.get('https://sentry.io/api/0/projects/devils/events/');
  await axios.post('https://events.amplitude.com/2/httpapi', payload);
}

export async function heartbeat(): Promise<Response> {
  return fetch('https://updates.license-server.example.com/check');
}
