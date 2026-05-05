# FSA-infrastructure

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

- Repozitár obsahuje `IaC` kód, `Kubernetes manifesty` a `Helm values` potrebné na postavenie a nasadenie celého stacku FullStack Akadémie.

---

## Model nasadenia

- Školiteľ pred workshopom pripraví infraštruktúru pre všetkých študentov v zdieľanej subscription.
- Každý študent dostane `Contributor` prístup iba na svoju `Resource Group` — vlastnú Azure subscription nepotrebuje.

```sh
Subscription (školiteľ)
├── rg-fsa-common          ← DNS zóna fullstackacademy.sk
├── rg-fsa                 ← AKS, ACR, PSQL, PIP školiteľa
├── rg-fsa-<student1>      ← plný stack študenta 1
└── rg-fsa-<student2>      ← plný stack študenta 2 ...
```

---

## Obsah repozitára

- [`terraform/`](./terraform/) — Azure infraštruktúra školiteľa (RG, ACR, AKS, PIP, PSQL, DNS). Postup a manuálne kroky → [terraform/README.md](./terraform/README.md).
- [`cookiecutter/`](./cookiecutter/) — generátor Terraform kódu pre študentov + postup pre nový ročník → [cookiecutter/README.md](./cookiecutter/README.md).
- [`kubernetes/`](./kubernetes/) — `Helm values`, `K8s manifesty` (ingress-nginx, GitLab, Keycloak, cert-manager). → [kubernetes/README.md](./kubernetes/README.md).
- [`docs/`](./docs/) — materiály pre študentov: diagramy, postupy, CI/CD šablóny.

---

## Repozitáre aplikácií

- [FSA-onion-architecture](https://github.com/posam/FSA-onion-architecture) — Backend (Java / Spring Boot)
- [FSA-angular](https://github.com/posam/FSA-angular) — Frontend (Angular / Nginx)

---

## Maintainer

- Radovan Pieter — [radovan.pieter@posam.sk](mailto:radovan.pieter@posam.sk)
