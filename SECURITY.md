# Security policy

## Supported version

Security fixes are applied to the latest revision of the `main` branch. This is
a portfolio and demonstration project; it is not offered as a managed service.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Contact the
maintainer through the email address listed on the GitHub profile:

https://github.com/seyedmohammadsinahosseini

Include the affected endpoint or component, reproduction steps, expected impact,
and any suggested mitigation. Do not include real credentials or personal data.

## Deployment requirements

A public deployment must:

- use HTTPS for the Web client and every API call;
- set `LMS_APP_ENV=production` and a strong random `LMS_APP_KEY`;
- keep `config/lms.env`, uploads, logs, JaaS keys, and signing keys outside the
  public document root and outside Git;
- configure an explicit `LMS_ALLOWED_ORIGINS` value;
- keep teacher self-registration disabled and use one-use invitations;
- use a dedicated least-privilege database user;
- retain independent database and private-file backups;
- use JaaS credentials for production Live rooms; and
- use an owner-controlled, backed-up Android release keystore.

Never publish `.env` files, database dumps containing user data, personal access
tokens, Android keystores, or private JaaS keys.
