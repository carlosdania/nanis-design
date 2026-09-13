import type { Response } from 'express';
import { ConnectorServiceError } from '../connectors/service.js';
import { sendApiError } from '../http/api-errors.js';
import { LiveArtifactRefreshAbortError } from './refresh.js';
import { LiveArtifactRefreshUnavailableError } from './refresh-service.js';
import {
  LiveArtifactRefreshLockError,
  LiveArtifactStoreValidationError,
} from './store.js';

export function sendLiveArtifactRouteError(res: Response, err: unknown): Response {
  if (err instanceof LiveArtifactStoreValidationError) {
    return sendApiError(res, 400, 'LIVE_ARTIFACT_INVALID', err.message, {
      details: {
        kind: 'validation',
        issues: err.issues.map((issue) => ({
          path: issue.path,
          message: issue.message,
        })),
      },
    });
  }
  if (err instanceof LiveArtifactRefreshLockError) {
    return sendApiError(res, 409, 'REFRESH_LOCKED', err.message, {
      details: { artifactId: err.artifactId },
    });
  }
  if (err instanceof LiveArtifactRefreshUnavailableError) {
    return sendApiError(res, 400, 'LIVE_ARTIFACT_REFRESH_UNAVAILABLE', err.message);
  }
  if (err instanceof LiveArtifactRefreshAbortError) {
    return sendApiError(res, err.kind === 'cancelled' ? 499 : 504, 'LIVE_ARTIFACT_REFRESH_TIMEOUT', err.message, {
      details: { kind: err.kind, timeoutMs: err.timeoutMs ?? null, step: err.step ?? null },
    });
  }
  if (err instanceof ConnectorServiceError) {
    return sendApiError(res, err.status, err.code, err.message, err.details === undefined ? {} : { details: err.details });
  }
  if (isNodeErrorWithCode(err, 'ENOENT')) {
    return sendApiError(res, 404, 'LIVE_ARTIFACT_NOT_FOUND', 'live artifact not found');
  }
  return sendApiError(res, 500, 'LIVE_ARTIFACT_STORAGE_FAILED', String(err));
}

// [carlos-studio patch] Allow the Studio panel (outer iframe host) as an
// ancestor of preview iframes; see routes/plugins/assets.ts for rationale.
const EXTRA_FRAME_ANCESTORS = process.env.OD_EXTRA_FRAME_ANCESTORS
  ?? 'http://localhost:4001 http://127.0.0.1:4001 https://carlos.nanis.ai';
const FRAME_ANCESTORS = ["'self'", ...EXTRA_FRAME_ANCESTORS.split(/\s+/).filter(Boolean)].join(' ');

export function setLiveArtifactPreviewHeaders(res: Response): void {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader(
    'Content-Security-Policy',
    [
      "default-src 'none'",
      "base-uri 'none'",
      "script-src 'none'",
      "object-src 'none'",
      "connect-src 'none'",
      "form-action 'none'",
      `frame-ancestors ${FRAME_ANCESTORS}`,
      "img-src 'self' data: blob:",
      "font-src 'self' data:",
      "style-src 'unsafe-inline'",
      'sandbox allow-same-origin',
    ].join('; '),
  );
}

export function setLiveArtifactCodeHeaders(res: Response): void {
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
}

function isNodeErrorWithCode(err: unknown, code: string): boolean {
  return Boolean(err && typeof err === 'object' && 'code' in err && err.code === code);
}
