# zPod Manual Testing Guide

**Last Updated:** 2026-01-08  
**Version:** 1.0

This comprehensive guide consolidates all manual testing procedures for the zPod application. Use this as the single source of truth for manual verification across all features.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Core Playback Testing](#core-playback-testing)
3. [Player UI Testing](#player-ui-testing)
4. [Error State Testing](#error-state-testing)
5. [VoiceOver Accessibility Testing](#voiceover-accessibility-testing)
6. [CarPlay Testing](#carplay-testing)
7. [Network Conditions Testing](#network-conditions-testing)
8. [Testing Checklist Summary](#testing-checklist-summary)

---

## Prerequisites

### Environment Setup

- [ ] macOS with Xcode installed
- [ ] iPhone 16 simulator (iOS 18.2+) available
- [ ] CarPlay simulator accessible (for CarPlay tests)
- [ ] Test podcast feeds loaded
- [ ] VoiceOver toggle shortcut known (⌘⇧⌥V)

### Test Data Requirements

- [ ] Podcasts with varying episode counts (0, 1, 50, 150+)
- [ ] Episodes with different duration lengths (< 5 min, 30 min, 2+ hours)
- [ ] Episodes with missing/invalid audio URLs (for error testing)
- [ ] Episodes with artwork and without artwork

### Debug Configuration (Optional)

For error state testing, enable debug controls:
- [ ] Edit Xcode scheme → Run → Arguments → Environment Variables
- [ ] Add: `ENABLE_ERROR_DEBUG=1`

---

## Core Playback Testing

### Test 1: Basic Playback Flow

**Objective:** Verify end-to-end playback works correctly

**Steps:**
1. Launch app
2. Navigate to Library → Select any podcast → Select any episode
3. Tap Play button
4. Observe mini-player appears at bottom
5. Verify audio starts playing
6. Verify progress slider advances
7. Verify current position updates
8. Tap Pause
9. Verify audio stops
10. Verify position preserved

**Expected Results:**
- ✅ Audio plays smoothly without stuttering
- ✅ Mini-player appears with correct episode info
- ✅ Progress slider reflects actual playback position
- ✅ Pause/resume works immediately
- ✅ Position preserved on pause

**Pass Criteria:** Audio plays reliably with accurate UI feedback

---

### Test 2: Skip Forward/Backward

**Objective:** Verify transport controls work correctly

**Steps:**
1. Start playing any episode
2. Note current position (e.g., 1:30)
3. Tap "Skip Forward" button
4. Verify position jumps ahead ~30 seconds (to ~2:00)
5. Tap "Skip Backward" button  
6. Verify position jumps back ~15 seconds (to ~1:45)
7. Test multiple rapid skips
8. Verify position updates accurately after each skip

**Expected Results:**
- ✅ Skip forward advances ~30 seconds
- ✅ Skip backward rewinds ~15 seconds
- ✅ Multiple skips work without lag
- ✅ Position updates visible immediately
- ✅ Audio resumes from new position

**Pass Criteria:** Skipping is responsive and accurate

---

### Test 3: Scrubbing/Seeking

**Objective:** Verify manual position adjustment works

**Steps:**
1. Play an episode (preferably 30+ minutes)
2. Tap expanded player to show full controls
3. Drag progress slider to middle of episode
4. Release slider
5. Verify audio jumps to new position
6. Verify position label updates correctly
7. Try scrubbing to beginning (0:00)
8. Try scrubbing to near end
9. Verify all positions accessible

**Expected Results:**
- ✅ Slider responds smoothly to touch
- ✅ Audio seeks to dragged position
- ✅ No crashes when seeking to boundaries
- ✅ Position labels accurate
- ✅ Playback resumes from new position

**Pass Criteria:** Scrubbing is smooth and accurate throughout episode

---

### Test 4: Background Playback

**Objective:** Verify playback continues when app is backgrounded

**Steps:**
1. Start playing an episode
2. Press Home button (⌘⇧H in simulator)
3. Wait 10 seconds
4. Open another app (e.g., Safari, Notes)
5. Verify audio continues playing
6. Return to zPod
7. Verify UI reflects current position
8. Verify playback state correct

**Expected Results:**
- ✅ Audio continues when app backgrounded
- ✅ Audio continues when other apps opened
- ✅ UI accurate when returning to app
- ✅ Lock screen controls work (if available)

**Pass Criteria:** Playback uninterrupted by app state changes

---

## Player UI Testing

### Test 5: Mini-Player Display

**Objective:** Verify mini-player shows correct information

**Steps:**
1. Play any episode
2. Observe mini-player at bottom of screen
3. Verify displays:
   - Episode title
   - Podcast title (or author)
   - Artwork (if available)
   - Play/Pause button
   - Progress indicator
4. Tap mini-player to expand
5. Verify smooth expansion animation
6. Drag down from top to collapse
7. Verify smooth collapse animation

**Expected Results:**
- ✅ All information visible and readable
- ✅ Artwork loads (if available)
- ✅ Tap expands to full player
- ✅ Drag-down collapses to mini-player
- ✅ Animations smooth (no jank)

**Pass Criteria:** Mini-player displays all info correctly with smooth animations

---

### Test 6: Expanded Player Layout

**Objective:** Verify full player shows all controls

**Steps:**
1. Expand player (tap mini-player)
2. Verify displays:
   - Large artwork (center)
   - Episode title
   - Podcast title
   - Current position / Total duration
   - Progress slider
   - Skip backward button
   - Play/Pause button
   - Skip forward button
   - Drag indicator (top)
3. Verify all elements properly aligned
4. Try rotating device (if applicable)
5. Verify layout adapts correctly

**Expected Results:**
- ✅ All controls visible
- ✅ Proper vertical spacing
- ✅ Artwork centered
- ✅ Labels readable
- ✅ Buttons properly sized (44pt min)

**Pass Criteria:** Layout is clean, organized, and all controls accessible

---

### Test 7: Playback Position Persistence

**Objective:** Verify position saved when switching episodes

**Steps:**
1. Play Episode A for 2 minutes
2. Navigate back to episode list
3. Play Episode B
4. After 30 seconds, return to Episode A
5. Tap Play on Episode A
6. Verify starts at ~2 minute mark (where left off)
7. Test with multiple episodes
8. Verify each episode remembers its position

**Expected Results:**
- ✅ Position saved per episode
- ✅ Resuming starts from saved position
- ✅ No loss of position when switching episodes
- ✅ Position persists across app launches

**Pass Criteria:** Every episode resumes from last played position

---

## Error State Testing

### Test 8: Network Error (Recoverable)

**Objective:** Verify network error handling in player

**Prerequisites:** Debug controls enabled (`ENABLE_ERROR_DEBUG=1`)

**Steps:**
1. Play any episode and expand player
2. Scroll down to find debug controls
3. Tap "Network" button
4. Observe error UI replaces player controls
5. Verify displays:
   - Large red error icon
   - "Playback Error" title
   - Error message: "Unable to load episode. Check your connection."
   - "Retry Playback" button (prominent)
   - Episode title and podcast below
6. Tap "Retry Playback" button
7. Observe behavior (may clear or persist depending on service state)

**Expected Results:**
- ✅ Error UI replaces normal controls immediately
- ✅ All elements visible and aligned (32pt consistent padding)
- ✅ Error message clear and actionable
- ✅ Retry button present and obvious
- ✅ Episode context helpful

**Pass Criteria:** Error state is clear, professional, and actionable

---

### Test 9: Timeout Error (Recoverable)

**Steps:**
1. With player expanded, find debug controls
2. Tap "Timeout" button
3. Observe error UI
4. Verify message: "The episode took too long to load."
5. Verify retry button present
6. Test retry behavior

**Expected Results:**
- ✅ Different message from network error
- ✅ Retry button still present
- ✅ UI consistent with network error state

---

### Test 10: Stream Failed Error (Non-Recoverable)

**Steps:**
1. With player expanded, find debug controls
2. Tap "Stream" button
3. Observe error UI
4. Verify message: "Unable to stream this episode."
5. **Verify NO retry button** (non-recoverable)
6. Tap "Clear Error" to restore

**Expected Results:**
- ✅ Error message clear
- ✅ NO retry button (user can't fix this)
- ✅ Episode context still shown
- ✅ User understands it's a permanent issue

---

### Test 11: Missing Audio URL Error (Non-Recoverable)

**Steps:**
1. With player expanded, find debug controls
2. Tap "Missing URL" button
3. Observe error UI
4. Verify message: "This episode doesn't have audio available."
5. **Verify NO retry button**
6. User must select different episode

**Expected Results:**
- ✅ Clear explanation of issue
- ✅ NO retry button
- ✅ User understands audio not available

---

### Test 12: Error Clearing

**Objective:** Verify errors clear appropriately

**Steps:**
1. Trigger any error (use debug controls)
2. Tap "Clear Error" button
3. Verify normal player UI returns
4. Verify playback can resume
5. Trigger error again
6. Navigate back and select different episode
7. Verify error clears when new episode starts

**Expected Results:**
- ✅ Clear button restores normal UI
- ✅ Switching episodes clears error
- ✅ No lingering error state
- ✅ Clean state transitions

---

## VoiceOver Accessibility Testing

### Prerequisites for VoiceOver Tests

**Enable VoiceOver:**
- Press **⌘⇧⌥V** in simulator (or Settings → Accessibility → VoiceOver → ON)
- You'll hear: "VoiceOver on"

**VoiceOver Gestures:**
| Gesture | Action |
|---------|--------|
| Swipe right | Next element |
| Swipe left | Previous element |
| Double tap | Activate element |
| Three-finger swipe | Scroll |
| Two-finger Z | Pause/resume VO |
| ⌘⇧⌥V | Toggle VO on/off |

---

### Test 13: Normal Player VoiceOver Navigation

**Objective:** Verify all player controls accessible via VoiceOver

**Steps:**
1. Play any episode
2. Expand to full player
3. Enable VoiceOver (⌘⇧⌥V)
4. Swipe right from top and listen to announcements
5. Expected order:
   - "Drag indicator"
   - "Artwork"
   - "[Episode Title]"
   - "[Podcast Title]"
   - "Progress slider, [percentage]"
   - "Skip backward, button. Jumps back fifteen seconds"
   - "Play, button" (or "Pause, button")
   - "Skip forward, button. Jumps ahead thirty seconds"

**Expected Results:**
- ✅ All elements announced in logical order
- ✅ Labels clear and descriptive
- ✅ Button actions described
- ✅ No redundant announcements
- ✅ No missing elements

**Verification Checklist:**
- [ ] Drag indicator announced (or skipped gracefully)
- [ ] Artwork announced
- [ ] Episode title read correctly
- [ ] Podcast title read correctly
- [ ] Progress slider announced with state
- [ ] All buttons have clear labels
- [ ] Button hints describe actions
- [ ] Navigation order top-to-bottom
- [ ] Double-tap activates controls correctly

**Pass Criteria:** VoiceOver user can understand and control playback

---

### Test 14: Error State VoiceOver - Network Error

**Objective:** Verify error states accessible via VoiceOver

**Steps:**
1. With VoiceOver enabled, trigger network error (debug controls)
2. Swipe right from top
3. Listen carefully to announcements
4. Expected order:
   - "Drag indicator"
   - **"Playback Error"** (title)
   - **"Unable to load episode. Check your connection."** (message)
   - **"Retry playback, button"** (action)
   - "[Episode Title]" (context)
   - "[Podcast Title]" (context)

**CRITICAL Verification:**
- [ ] ❌ Does NOT announce "Error" or "Exclamation mark" (icon hidden)
- [ ] ✅ "Playback Error" title clear
- [ ] ✅ Full error message read (not truncated)
- [ ] ✅ "Retry playback" button label clear
- [ ] ✅ Episode context provides useful info
- [ ] ✅ Navigation order logical
- [ ] ✅ Double-tap on retry button works

**Expected Results:**
- ✅ Error icon NOT announced (`.accessibilityHidden(true)`)
- ✅ Title and message clear
- ✅ Retry button actionable
- ✅ Context helpful
- ✅ No confusion about state

**Pass Criteria:** VoiceOver user understands error and can retry

---

### Test 15: Error State VoiceOver - Non-Recoverable Errors

**Objective:** Verify non-recoverable errors accessible

**Steps:**
1. With VoiceOver enabled, trigger "Stream Failed" error
2. Swipe through elements
3. Expected:
   - "Playback Error"
   - "Unable to stream this episode."
   - [Episode Title] (NO retry button between)
   - [Podcast Title]
4. Repeat for "Missing URL" error
5. Verify same pattern (no retry button)

**Expected Results:**
- ✅ Error explained clearly
- ✅ NO retry button announced
- ✅ User understands it's permanent
- ✅ Can navigate away to select different episode

**Pass Criteria:** VoiceOver user understands error is not recoverable

---

### Test 16: Mini-Player VoiceOver

**Objective:** Verify mini-player accessible

**Steps:**
1. With VoiceOver on, play episode
2. Navigate to mini-player at bottom
3. Swipe through elements
4. Expected announcements:
   - "[Episode Title]"
   - "[Podcast Title]"
   - "Play, button" (or "Pause, button")
   - (Optional: Progress indicator)
5. Double-tap mini-player to expand
6. Verify expansion works

**Expected Results:**
- ✅ All mini-player info announced
- ✅ Tap target clear ("mini player" or similar)
- ✅ Can expand with double-tap
- ✅ State changes announced (play/pause)

---

## CarPlay Testing

**Note:** CarPlay testing requires macOS environment. See `docs/carplay/MANUAL_TESTING_CHECKLIST.md` for complete 44-point checklist.

### Test 17: Quick CarPlay Smoke Test

**Prerequisites:**
- macOS with Xcode
- CarPlay simulator enabled (I/O → External Displays → CarPlay)

**Steps:**
1. Launch app on device/simulator
2. Enable CarPlay display
3. Verify zpod app appears in CarPlay
4. Tap zpod icon
5. Verify podcast list loads
6. Select a podcast
7. Verify episode list loads
8. Select an episode
9. Verify play/queue/cancel alert appears
10. Tap "Play"
11. Verify audio starts and Now Playing appears

**Expected Results:**
- ✅ App loads in CarPlay
- ✅ Lists display correctly
- ✅ Touch targets adequate (≥44pt)
- ✅ Text readable
- ✅ Playback works
- ✅ No crashes

**For Complete Testing:** Follow full checklist in `docs/carplay/MANUAL_TESTING_CHECKLIST.md`

---

## Network Conditions Testing

### Test 18: Slow Network

**Objective:** Verify app handles slow connections gracefully

**Steps:**
1. Enable Network Link Conditioner (macOS)
2. Set to "3G" or "Edge" profile
3. Launch app
4. Navigate to a podcast with many episodes
5. Observe loading behavior
6. Attempt to play an episode
7. Observe buffering behavior

**Expected Results:**
- ✅ App doesn't hang or freeze
- ✅ Loading indicators shown
- ✅ Episodes eventually load
- ✅ Playback starts (may buffer)
- ✅ User informed of delays
- ✅ No crashes or timeouts

---

### Test 19: Network Interruption

**Objective:** Verify graceful handling of network loss

**Steps:**
1. Start playing an episode
2. Enable Airplane Mode (Control Center)
3. Observe player behavior
4. Wait 10 seconds
5. Disable Airplane Mode
6. Observe recovery

**Expected Results:**
- ✅ Playback pauses or shows error
- ✅ User notified of connection issue
- ✅ Retry option available (if applicable)
- ✅ Playback resumes when network restored
- ✅ No data corruption

---

## Testing Checklist Summary

Use this high-level checklist to track manual testing completion:

### Core Functionality
- [ ] Test 1: Basic Playback Flow
- [ ] Test 2: Skip Forward/Backward
- [ ] Test 3: Scrubbing/Seeking
- [ ] Test 4: Background Playback

### Player UI
- [ ] Test 5: Mini-Player Display
- [ ] Test 6: Expanded Player Layout
- [ ] Test 7: Playback Position Persistence

### Error States
- [ ] Test 8: Network Error (Recoverable)
- [ ] Test 9: Timeout Error (Recoverable)
- [ ] Test 10: Stream Failed Error (Non-Recoverable)
- [ ] Test 11: Missing Audio URL Error (Non-Recoverable)
- [ ] Test 12: Error Clearing

### VoiceOver Accessibility
- [ ] Test 13: Normal Player VoiceOver Navigation
- [ ] Test 14: Error State VoiceOver - Network Error
- [ ] Test 15: Error State VoiceOver - Non-Recoverable Errors
- [ ] Test 16: Mini-Player VoiceOver

### CarPlay
- [ ] Test 17: Quick CarPlay Smoke Test
  - [ ] Full CarPlay Checklist (if required)

### Network Conditions
- [ ] Test 18: Slow Network
- [ ] Test 19: Network Interruption

---

## Testing Notes Template

Use this template to document your testing session:

```
## Manual Testing Session

**Date:** ___________
**Tester:** ___________
**Device:** iPhone 16 Simulator / Real Device (iOS ___)
**Build:** Branch/Commit ___________

### Tests Completed
- [ ] List tests performed
- [ ] Note any failures or issues

### Issues Found
1. **Issue:** Description
   - **Severity:** Critical / High / Medium / Low
   - **Steps to Reproduce:**
   - **Expected:**
   - **Actual:**
   - **Screenshot:** (if applicable)

### Notes
- Any observations
- Performance concerns
- Suggestions

### Overall Assessment
✅ Pass / ⚠️ Pass with Issues / ❌ Fail

**Sign-off:** ___________
```

---

## Related Documentation

- **VoiceOver Testing:** `VOICEOVER_TESTING_GUIDE.md` (detailed guide)
- **CarPlay Testing:** `docs/carplay/MANUAL_TESTING_CHECKLIST.md` (44-point checklist)
- **UI Testing Best Practices:** `docs/testing/ACCESSIBILITY_TESTING_BEST_PRACTICES.md`
- **Automated Tests:** See `zpodUITests/` for UI test coverage

---

## Quick Reference

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| VoiceOver not working | Press ⌘⇧⌥V multiple times; restart simulator |
| Debug controls not showing | Check `ENABLE_ERROR_DEBUG=1` in Xcode scheme |
| CarPlay not appearing | Enable I/O → External Displays → CarPlay |
| Audio not playing | Check volume; verify test feed has valid URLs |
| Slow performance | Disable animations; reset simulator |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘R | Build and run |
| ⌘. | Stop running |
| ⌘⇧H | Home button (simulator) |
| ⌘⇧⌥V | Toggle VoiceOver |
| ⌘K | Clear console |

---

**Last Updated:** 2026-01-08  
**Maintained by:** zPod Development Team

For questions or updates to this guide, see `dev-log/` or open an issue.
