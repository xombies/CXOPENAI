'use client';

import { useEffect, useRef } from 'react';

export function useDevServerHeartbeat() {
  if (import.meta.env.PROD) {
    return;
  }

  const lastPingAtMs = useRef(0);

  useEffect(() => {
    const throttleMs = 3 * 60_000;

    const maybePing = () => {
      const now = Date.now();
      if (now - lastPingAtMs.current < throttleMs) {
        return;
      }
      lastPingAtMs.current = now;

      fetch('/', {
        method: 'GET',
      }).catch(() => {});
    };

    const events = ['pointerdown', 'keydown', 'mousemove', 'scroll', 'touchstart'] as const;
    for (const event of events) {
      window.addEventListener(event, maybePing, { passive: true });
    }

    return () => {
      for (const event of events) {
        window.removeEventListener(event, maybePing);
      }
    };
  }, []);
}
