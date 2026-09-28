# Dedup

Dedup is a native macOS application for finding byte-for-byte duplicate media and safely organizing original footage. It supports very large files and local or network-attached storage.

Files are duplicates only when their sizes and complete SHA-256 hashes match. Filenames and related media formats do not determine duplication.

## Workflow

1. Choose a source folder and an Originals destination.
2. Analyze the folders and review exact duplicates, problems, and the generated operation plan.
3. Run the plan in dry-run mode and optionally copy its detailed report.
4. Disable dry run and execute the reviewed plan.

Unique files are organized beneath `Audio`, `Photos`, or `Videos` using `YYYY/MM/DD` creation-date folders. Exact source duplicates of target content are moved to `.Dedup Quarantine`; they are never deleted automatically.

Same-filesystem transfers use an atomic move. Cross-filesystem transfers stream to a hidden staging file, fully verify both source and copy, commit the copy, and only then remove the source. Cancelling removes partial staging data and leaves the source intact.

For complete build, usage, testing, safety, and licensing information, see the repository's top-level `README.md`.

Dedup is released under the MIT License.
