# CarPlay Manual Testing Checklist

This checklist guides manual validation of the zpod CarPlay implementation in the CarPlay simulator. Use this to complete the validation started in Issue 02.1.8.2.

## Prerequisites

Before starting manual testing, ensure:

- [ ] macOS environment with Xcode installed
- [ ] CarPlay simulator enabled (I/O → External Displays → CarPlay)
- [ ] Siri enabled in simulator: `xcrun simctl spawn booted defaults write com.apple.Siri SiriEnabled -bool true`
- [ ] Test podcasts loaded with varying episode counts (0, 1, 50, 150+ episodes)
- [ ] VoiceOver can be toggled on/off for accessibility testing
- [ ] "Limit UI While Driving" setting accessible for motion testing

## Section 1: Touch Target Validation

**Objective**: Verify all interactive elements meet 44pt minimum touch target size.

- [ ] Open CarPlay simulator and launch zpod
- [ ] Navigate to podcast list
- [ ] Verify each podcast item is easily tappable (not too small)
- [ ] Select a podcast and navigate to episode list
- [ ] Verify each episode item is easily tappable
- [ ] Trigger episode action alert (Play/Queue/Cancel)
- [ ] Verify all three action buttons are easily tappable
- [ ] Take screenshots showing touch target sizes
- [ ] Measure touch targets in screenshots (should be ≥44pt)

**Expected**: All interactive elements have clear, large touch targets that are easy to tap while driving.

**Pass Criteria**: No items feel too small or cramped; all buttons are comfortably tappable.

---

## Section 2: Text Contrast and Readability

**Objective**: Verify text is readable at highway speeds in various lighting conditions.

### Light Mode Testing
- [ ] Enable light mode (if not default)
- [ ] Take screenshot of podcast list
- [ ] Take screenshot of episode list
- [ ] Verify podcast titles are high contrast and readable
- [ ] Verify episode titles are high contrast and readable
- [ ] Verify detail text (duration, episode count) is legible
- [ ] Check that truncated titles (40+ chars) remain readable

### Dark Mode Testing
- [ ] Switch to dark mode
- [ ] Take screenshot of podcast list
- [ ] Take screenshot of episode list
- [ ] Verify high contrast maintained in dark mode
- [ ] Verify no readability degradation from light mode

### Lighting Conditions
- [ ] Review screenshots under bright lighting
- [ ] Review screenshots under dim lighting
- [ ] Simulate quick glance (< 2 seconds) readability

**Expected**: All text should be immediately readable with high contrast in both light and dark modes.

**Pass Criteria**: Text can be read in a quick glance without straining; no low-contrast combinations.

---

## Section 3: Motion Safety Compliance

**Objective**: Verify interface complies with safety guidelines when vehicle is in motion.

- [ ] Enable "Limit UI While Driving" in simulator settings
- [ ] Launch zpod in CarPlay
- [ ] Verify podcast list still navigable (should be allowed)
- [ ] Select a podcast to view episodes
- [ ] Verify episode selection still works (should be allowed)
- [ ] Trigger episode action alert
- [ ] Verify all actions (Play/Queue/Cancel) are accessible
- [ ] Confirm no text entry prompts appear anywhere
- [ ] Verify no multi-step wizards or complex flows
- [ ] Check that cancel button is always visible
- [ ] Verify actions complete quickly (< 2 seconds)
- [ ] Confirm no scrolling required to reach primary actions

**Expected**: All essential functions remain available during motion; no unsafe interactions presented.

**Pass Criteria**: No text entry, no complex flows, cancel always available, actions quick.

---

## Section 4: List Management

**Objective**: Verify list depth limits and content organization.

### Episode Count Testing
- [ ] Load podcast with < 100 episodes
- [ ] Verify all episodes are shown
- [ ] Count episodes in list (should match actual count)
- [ ] Load podcast with exactly 100 episodes
- [ ] Verify all 100 episodes shown
- [ ] Load podcast with > 100 episodes (e.g., 150)
- [ ] Verify only 100 episodes shown
- [ ] Confirm most recent 100 episodes displayed

### Sorting and Organization
- [ ] Verify episodes sorted newest-first in list
- [ ] Check first episode has most recent publication date
- [ ] Verify podcasts in library sorted alphabetically
- [ ] Confirm alphabetical sorting case-insensitive

### Empty States
- [ ] Load podcast with 0 episodes
- [ ] Verify list header shows "No Episodes"
- [ ] Confirm UI handles empty state gracefully

**Expected**: Lists limited to 100 items, properly sorted, empty states handled.

**Pass Criteria**: All list limits enforced, sorting correct, no crashes on empty data.

---

## Section 5: Siri Voice Commands

**Objective**: Test voice control integration and natural language support.

### Basic Commands
- [ ] Say "Hey Siri, play [exact podcast name]"
- [ ] Verify podcast starts playing
- [ ] Say "Hey Siri, play [exact episode title]"
- [ ] Verify episode starts playing
- [ ] Say "Hey Siri, play the latest episode of [podcast]"
- [ ] Verify newest episode starts playing

### Fuzzy Matching
- [ ] Say "Hey Siri, play [podcast name with typo]"
- [ ] Verify Siri finds correct podcast despite typo
- [ ] Say "Hey Siri, play the newest episode"
- [ ] Verify temporal reference parsed correctly
- [ ] Say "Hey Siri, play recent episodes"
- [ ] Verify "recent" understood

### Disambiguation
- [ ] Say ambiguous query (matches multiple podcasts/episodes)
- [ ] Verify Siri prompts for clarification
- [ ] Select from disambiguation list
- [ ] Verify correct item plays
- [ ] Say "cancel" during disambiguation
- [ ] Verify returns to previous screen

### Error Handling
- [ ] Say "Hey Siri, play [nonexistent podcast]"
- [ ] Verify error message shown (not found)
- [ ] Say "Hey Siri, play episode" (no context)
- [ ] Verify Siri asks for clarification
- [ ] Document error messages shown

**Expected**: Voice commands work reliably, fuzzy matching handles typos, disambiguation prompts when needed.

**Pass Criteria**: All test commands succeed, errors handled gracefully, prompts are clear.

---

## Section 6: VoiceOver Navigation

**Objective**: Verify full accessibility for VoiceOver users.

- [ ] Enable VoiceOver in simulator
- [ ] Navigate to zpod in CarPlay
- [ ] Use VoiceOver gestures to navigate podcast list
- [ ] Verify each podcast has descriptive label (title)
- [ ] Verify each podcast has actionable hint ("Double tap to view episodes")
- [ ] Navigate to episode list via VoiceOver
- [ ] Verify each episode has descriptive label (title)
- [ ] Verify each episode has actionable hint ("Double tap to play")
- [ ] Trigger episode action alert with VoiceOver
- [ ] Verify all actions (Play/Queue/Cancel) accessible
- [ ] Verify VoiceOver announces action button labels clearly
- [ ] Navigate entire interface using only VoiceOver
- [ ] Disable VoiceOver

**Expected**: Complete interface navigation possible with VoiceOver; all elements have proper labels/hints.

**Pass Criteria**: VoiceOver user can accomplish all tasks; labels clear and hints actionable.

---

## Section 7: Visual Polish and UX

**Objective**: Verify visual presentation quality and user experience.

### Visual Elements
- [ ] Check episode artwork displays (if implemented)
- [ ] Verify list item spacing is consistent
- [ ] Check alignment of text elements
- [ ] Verify playback progress indicator shows for in-progress episodes
- [ ] Check if currently playing episode is highlighted (if implemented)

### Title Truncation
- [ ] Find episode with very long title (40+ characters)
- [ ] Verify title truncated with ellipsis
- [ ] Check truncation doesn't break at odd position
- [ ] Verify truncated title still readable

### Navigation Transitions
- [ ] Navigate from podcast list to episode list
- [ ] Verify transition is smooth (< 0.3 seconds)
- [ ] Navigate back to podcast list
- [ ] Verify back navigation smooth
- [ ] Present and dismiss action alert
- [ ] Verify alert animations appropriate

### Overall Experience
- [ ] Test rapid navigation (tap multiple items quickly)
- [ ] Verify no lag or stuttering
- [ ] Check for any visual glitches
- [ ] Verify interface feels polished and professional

**Expected**: Professional visual presentation, smooth animations, consistent styling.

**Pass Criteria**: No visual glitches, transitions smooth, UI feels polished.

---

## Section 8: Integration Testing

**Objective**: Verify integration with playback engine and queue management.

### Playback Integration
- [ ] Select episode and choose "Play Now"
- [ ] Verify episode starts playing in Now Playing screen
- [ ] Check Now Playing template shows correct episode info
- [ ] Verify playback controls work (play/pause/skip)
- [ ] Return to episode list
- [ ] Verify episode marked as in-progress (if played partially)

### Queue Management
- [ ] Select episode and choose "Add to Queue"
- [ ] Verify episode added to queue (check logs or UI)
- [ ] Queue multiple episodes
- [ ] Verify queue order correct
- [ ] Play queue episodes
- [ ] Verify queue advances automatically

### State Persistence
- [ ] Play episode partially
- [ ] Disconnect from CarPlay
- [ ] Reconnect to CarPlay
- [ ] Verify playback state preserved
- [ ] Verify in-progress indicator shows

**Expected**: Full integration with playback engine; queue management works; state persists.

**Pass Criteria**: Playback works reliably, queue functions correctly, state preserved across sessions.

---

## Post-Testing Documentation

After completing all sections:

### 1. Update Documentation
- [ ] Add screenshots to CARPLAY_HIG_COMPLIANCE.md
- [ ] Document any issues found
- [ ] Update test results section with findings
- [ ] Mark manual testing as complete

### 2. Track Issues
- [ ] Create follow-up issues for any problems found
- [ ] Document workarounds if needed
- [ ] Prioritize issues (critical vs. enhancement)

### 3. Sign-Off
- [ ] Review all checklist items completed
- [ ] Verify all screenshots captured
- [ ] Confirm compliance with HIG
- [ ] Update issue status to COMPLETE

---

## Results Summary Template

Copy this template to CARPLAY_HIG_COMPLIANCE.md after testing:

```markdown
## Manual Testing Results

**Testing Date**: [DATE]  
**Environment**: macOS [VERSION], Xcode [VERSION], iOS Simulator [VERSION]  
**Tester**: [NAME]

### Touch Targets
**Status**: [ ] Pass / [ ] Fail  
**Notes**: 

### Text Contrast
**Status**: [ ] Pass / [ ] Fail  
**Screenshots**: [Link to screenshots]  
**Notes**: 

### Motion Safety
**Status**: [ ] Pass / [ ] Fail  
**Notes**: 

### List Management
**Status**: [ ] Pass / [ ] Fail  
**Notes**: 

### Siri Voice Commands
**Status**: [ ] Pass / [ ] Fail  
**Tested Commands**: 
- [ ] Play [podcast]
- [ ] Play latest episode
- [ ] Disambiguation
- [ ] Error handling
**Notes**: 

### VoiceOver Navigation
**Status**: [ ] Pass / [ ] Fail  
**Notes**: 

### Visual Polish
**Status**: [ ] Pass / [ ] Fail  
**Screenshots**: [Link to screenshots]  
**Notes**: 

### Integration
**Status**: [ ] Pass / [ ] Fail  
**Notes**: 

### Overall HIG Compliance
**Status**: [ ] COMPLIANT / [ ] NON-COMPLIANT  
**Issues Found**: [Number]  
**Critical Issues**: [Number]  
**Enhancement Opportunities**: [Number]

### Recommendations
1. 
2. 
3. 
```

---

## Reference Links

- [CARPLAY_HIG_COMPLIANCE.md](./CARPLAY_HIG_COMPLIANCE.md) - Full compliance documentation
- [CARPLAY_SETUP.md](./CARPLAY_SETUP.md) - Setup instructions
- [Issues/02.1.8.2-carplay-hig-validation.md](./Issues/02.1.8.2-carplay-hig-validation.md) - Issue details
- [dev-log/02.1.8.2-carplay-hig-validation.md](./dev-log/02.1.8.2-carplay-hig-validation.md) - Validation timeline

---

**Total Test Scenarios**: 44  
**Estimated Testing Time**: 2-3 hours  
**Required Environment**: macOS with Xcode and CarPlay simulator
