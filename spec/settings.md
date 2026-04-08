# Spec: Settings

---

## OPML Import

**Issue**: #451
**Feature**: Import OPML file picker and result feedback in Settings

---

### Scenarios

#### AC1: Import row is present in Settings

```
Given the user is on the Settings tab
When they view the "Data & Subscriptions" section
Then an "OPML Import" navigation row is present and hittable
And it carries accessibilityIdentifier "Settings.DataSubscriptions.OPMLImport"
```

#### AC1: Import screen shows the action button

```
Given the user navigates to Settings → OPML Import
When the screen loads
Then a "Import Subscriptions (OPML)" button is present and enabled
And it carries accessibilityIdentifier "Settings.ImportOPML"
```

#### AC2: Tapping import presents the file picker

```
Given the user is on the OPML Import screen
When they tap "Import Subscriptions (OPML)"
Then the system document picker (UIDocumentPickerViewController) appears
And only .xml files are selectable
```

#### AC2: Import button is disabled while import is in progress

```
Given an OPML import is in progress
When the OPML Import screen is visible
Then the "Import Subscriptions (OPML)" button is disabled
And a progress indicator with label "Importing…" is shown
```

#### AC3: Result sheet appears after successful import

```
Given the user selects a valid OPML file containing N podcast feeds
When all feeds import successfully
Then a result sheet appears
And it shows "Imported N of N podcasts" with a green checkmark
And the sheet carries accessibilityIdentifier "Settings.ImportOPML.Result"
And a "Done" button dismisses the sheet
```

#### AC3: Result sheet shows partial failure summary

```
Given the user selects a valid OPML file where some feeds fail
When the import completes with M successes and K failures
Then the result sheet appears showing "Imported M of (M+K) podcasts" with an orange warning icon
And a "Failed Feeds" section lists each failed URL and its error message
```

#### AC4: Error alert on invalid OPML file

```
Given the user selects a file that is not valid OPML
When the import service rejects it
Then an "Import Error" alert appears
And the message reads "The selected file is not a valid OPML file."
And tapping "OK" dismisses the alert
```

#### AC4: Error alert when no podcast feeds found

```
Given the user selects a valid OPML file that contains no podcast feed URLs
When the import service finds no feeds
Then an "Import Error" alert appears
And the message reads "No podcast feeds were found in the selected file."
```

#### AC5: Error alert on general import failure

```
Given the user selects an OPML file and an unexpected error occurs during import
When the import service throws an unrecognised error
Then an "Import Error" alert appears
And the message contains the underlying error description
```

#### AC1: Back navigation returns to Settings

```
Given the user is on the OPML Import screen
When they tap the back button
Then they return to the Settings home screen
```
