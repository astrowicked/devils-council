# Plan: Add user preferences page

Users should be able to set their display name and avatar URL. The page
renders at /preferences and calls the existing /api/user PATCH endpoint.

## Tasks
1. Create preferences.tsx component
2. Wire to /api/user PATCH
3. Add navigation link

## Done when
- User can update display name
- User can update avatar URL
