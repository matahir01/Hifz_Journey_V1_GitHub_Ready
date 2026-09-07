# Hifz Journey V2.1.1 Audio Architecture

## Provider

V2.1.1 uses Al Quran Cloud / Islamic Network CDN as the single online provider. Hifz Journey does not require a Quran Foundation account, OAuth secret, or application backend for this path.

The provider resolves each global ayah number to:

`https://cdn.islamic.network/quran/audio/{bitrate}/{edition}/{globalAyahNumber}.mp3`

The selected `AudioReciter` supplies the documented Al Quran Cloud edition identifier and bitrate.

## Playback decision

For each ayah:

1. Check Hifz Journey private storage for the selected reciter.
2. If a matching file exists, play it locally.
3. Otherwise resolve the Al Quran Cloud CDN URL and stream it.
4. A manually imported local ayah can act as a fallback.

## Synchronization

The player publishes the active `ayah_id` before each verse starts. Reader mode listens to that stream, advances to the corresponding verse, and highlights it. Because V2 uses one MP3 per ayah, no timestamp server is required for ayah-level synchronization.

Word-by-word highlighting is intentionally not part of V2 because the selected provider does not supply reliable reciter-specific word timing data through this simple ayah-CDN path.

## Offline downloads

`AudioLibraryService` downloads user-selected ayahs/Surahs to the application support directory. Database metadata tracks the reciter, source URL, local path and download date. Partial files use a `.part` suffix and are removed on failure.

## Provider isolation

The rest of the Reader and Hifz UI depends on `QuranAudioProvider`, not on CDN URL construction. This keeps the player architecture maintainable even though V2 intentionally ships with one online provider.
