## Problem and resulting behavior

Related issue(s): Refs # (required; link rubric issue). Use Closes only when the whole issue acceptance/DoD is met, not merely its W1 slice.

Owner:
Reviewers (another member; M2 UI/Auth, M3 security):
Rubric IDs / W1 slice:

Describe what changes for the user and any material limitation.

## Validation and evidence

| Platform / check | Command or steps | Result / evidence |
| --- | --- | --- |
| Format / analyze / tests | | |
| Web build + behavior | | |
| Android build + behavior | | |

Do not label fake tests as Firebase verification. Build success does not prove runtime behavior.

## Contracts, schema and rules

Changed contract/schema/rules? If yes, link owner review, migration and related rule changes. Otherwise write none. Explain UID/listener/cache isolation and known blockers where relevant.

- [ ] No credentials/passwords/admin keys in source, logs or evidence
- [ ] Scope respects M1/M2/M3 ownership
- [ ] Another member reviewed; author did not self-approve
- [ ] QA/evidence sufficient before merge; no unverified Gate/Done claims
