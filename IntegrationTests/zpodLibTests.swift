2025-08-20
---
Issue: Duplicate package error ('found multiple top-level packages named FeedParsing') during build after refactor.

Diagnosis: Packages/Networking/Package.swift was incorrectly named 'FeedParsing' and exposed a 'FeedParsing' target, causing Xcode to detect two top-level packages named FeedParsing.

Fix: Renamed Networking package to 'Networking', updated product and target names, and added FeedParsing as a dependency instead of a duplicate package.

Next: Committing fix and retrying build/tests to confirm resolution.

2025-08-21
---
Progress Update: Test files have been moved from zpodTests/ to their correct package test folders as part of modularization:
- Issue05AcceptanceCriteriaTests.swift → SettingsDomain/Tests/
- Issue08SearchTests.swift → CoreModels/Tests/
- Issue11OPMLTests.swift → FeedParsing/Tests/

The original files have been removed from zpodTests/ after confirming their presence in the correct locations. Remaining test migration tasks:
- Review and migrate zpodLibTests.swift (integration test; may need a dedicated IntegrationTests target or remain in main app test target)
- Confirm all package test folders are up to date and no duplicate tests remain

Next: Commit these changes to git and continue with any remaining test migration or cleanup.

2025-08-21 14:30
---
Progress Update: Migrated zpodLibTests.swift from zpodTests/ to IntegrationTests/ at the workspace root. This follows best practices for integration testing and keeps package boundaries clean.

All package test folders have been reviewed and are up to date. No duplicate or orphaned test files remain in zpodTests/.

Next: Commit these changes to git and run all tests to confirm the migration is successful and the test suite passes.
