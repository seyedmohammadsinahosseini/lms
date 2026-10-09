# Contributing

Thank you for your interest in LMS. This repository is maintained as a portfolio
project, but focused bug reports and well-scoped pull requests are welcome.

## Before opening a pull request

1. Open an issue for substantial behavior or schema changes.
2. Keep production secrets and real user data out of commits, screenshots, and
   test fixtures.
3. Preserve the stable `/api/v1` contract or document an intentional migration.
4. Add or update tests for behavior changes.
5. Run the relevant checks:

```bash
find backend tools -type f -name '*.php' -print0 | xargs -0 -n1 php -l
shellcheck tools/*.sh
cd lms_flutter && flutter analyze && flutter test
```

Each backend API suite requires its own fresh database imported from
`backend/schema.sql`; CI creates these databases automatically.

Use clear commit messages and complete the pull-request template. Security
reports must follow [SECURITY.md](SECURITY.md), not a public issue.
