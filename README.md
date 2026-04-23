# MOLLER-parity-schema
Schema for the MOLLER experiment analysis database. Uses dbml to generically define the schema, which is then turned into the sql for MySQL and postgresql databases. Diagram generated. Versioned at 1.4, per Qweak versioning, so significant changes (likely) would bring us to v2 (semver with backwards incompatible defined as more than addition of nullable fields or addition of tables).

<img src='https://jeffersonlab.github.io/MOLLER-parity-schema/qwparity_schema.svg' alt='MOLLER Parity Schema' />

## Releases

When a new release is created, SQL commands for MySQL and PostgreSQL are automatically generated from the DBML schema and attached to the release as assets.

