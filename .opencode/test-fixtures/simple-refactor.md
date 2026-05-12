# Plan: Rename getUserData to fetchUserProfile

## Summary

Rename the `getUserData` utility function to `fetchUserProfile` across the codebase
for clarity. The current name is ambiguous — it could mean fetching from cache,
database, or API. The new name makes the intent explicit.

## Changes

### 1. Rename in source

```typescript
// src/utils/helpers.ts
// Before:
export function getUserData(id: string): UserProfile {
  return profileCache.get(id);
}

// After:
export function fetchUserProfile(id: string): UserProfile {
  return profileCache.get(id);
}
```

### 2. Move to dedicated module

Move from `src/utils/helpers.ts` to `src/services/profile.ts` since it's
a service-layer concern, not a generic utility.

### 3. Update callers

```typescript
// src/components/Dashboard.tsx
// Before:
const user = getUserData(userId);

// After:
const user = fetchUserProfile(userId);
```

### 4. Add JSDoc

```typescript
/**
 * Retrieves the user profile from the in-memory cache.
 * Returns undefined if the profile has not been loaded.
 */
export function fetchUserProfile(id: string): UserProfile | undefined {
  return profileCache.get(id);
}
```

## Verification

- All existing tests pass (rename only, no logic change)
- No new dependencies added
- Type signatures unchanged
