# dbt-project : guide dbt avec PostgreSQL

Projet pédagogique réalisé dans le cadre d'un BootCamp pour comprendre le
fonctionnement d'un projet dbt de bout en bout : chargement de données brutes,
transformation SQL, tests de qualité, snapshot et exposition de tables
analytiques dans PostgreSQL.

## Sommaire

- [📚 Qu'est-ce que dbt ?](#-quest-ce-que-dbt-)
- [🎯 Description du projet](#-description-du-projet)
- [🏗️ Architecture des transformations](#️-architecture-des-transformations)
- [📁 Structure du projet](#-structure-du-projet)
- [🚀 Installation et lancement](#-installation-et-lancement)
- [⌨️ Commandes dbt expliquées](#️-commandes-dbt-expliquées)
- [🔎 Consulter les données avec Adminer](#-consulter-les-données-avec-adminer)
- [✅ Tests de qualité](#-tests-de-qualité)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [📨 Contact](#-contact)

## 📚 Qu'est-ce que dbt ?

**dbt (data build tool)** est un outil qui permet de transformer des données
dans un entrepôt de données en utilisant principalement SQL et Jinja.
Contrairement à un outil d'ingestion, dbt ne collecte pas les données depuis
les sources : il exécute des transformations directement dans la base de
données.

dbt apporte notamment :

- des modèles SQL versionnés avec Git ;
- des dépendances entre modèles grâce à `ref()` ;
- des sources déclarées avec `source()` ;
- des tests de qualité et de cohérence ;
- la documentation du projet et de ses colonnes ;
- les snapshots, qui conservent l'historique des changements.

Il est fréquemment utilisé dans les architectures analytiques modernes entre
une zone de données brutes et les tables destinées à la BI, au reporting ou au
machine learning.

## 🎯 Description du projet

Le projet simule une plateforme d'analyse de trajets. Les fichiers CSV
représentent les données sources :

- les conducteurs ;
- les véhicules ;
- les zones ;
- les trajets.

Le pipeline charge ces CSV dans PostgreSQL, nettoie les données, enrichit les
trajets avec les conducteurs et les véhicules, puis construit des tables
analytiques :

| Couche | Rôle | Matérialisation |
| --- | --- | --- |
| `seeds` | Charger les CSV bruts dans PostgreSQL | Tables |
| `staging` | Renommer et typer les colonnes sources | Vues |
| `intermediate` | Enrichir les trajets et appliquer la logique métier | Éphémère |
| `marts` | Produire les tables finales pour l'analyse | Tables |
| `snapshots` | Historiser les changements de notation des conducteurs | Tables |

## 🏗️ Architecture des transformations

```text
CSV sources
    │
    ▼
seeds/raw_drivers ─────► staging/stg_drivers ─────► snapshots/drivers_snapshot
seeds/raw_vehicles ────► staging/stg_vehicles ───────────────┐
seeds/raw_zones ───────► staging/stg_zones ─────► marts/dim_zone
seeds/raw_ride_events ► staging/stg_ride_events ─────────────┐
                                                            ▼
                                                   intermediate/
                                                   int_rides_enriched
                                                            │
                              ┌─────────────────────────────┴────────────────────┐
                              ▼                                                  ▼
                       marts/fact_rides                             marts/dim_vehicle
                              │
                              ▼
                 marts/fct_driver_daily_earnings
```

Les seeds alimentent les modèles staging. Le snapshot conserve l'historique
des changements de notation des conducteurs. Le modèle intermédiaire enrichit
les trajets avec les conducteurs et les véhicules, puis alimente la table de
faits `fact_rides`. Les modèles `dim_zone` et `dim_vehicle` sont des dimensions
analytiques, tandis que `fct_driver_daily_earnings` calcule les revenus
quotidiens, le cumul et le classement des conducteurs.

## 📁 Structure du projet

| Chemin | Rôle | Ce que l'on peut y ajouter |
| --- | --- | --- |
| `docker-compose.yml` | Lance PostgreSQL et Adminer | D'autres services locaux |
| `dbt/dbt_project.yml` | Configuration du projet dbt | Variables, chemins, matérialisations |
| `dbt/profiles.yml` | Connexion locale à PostgreSQL | Des environnements `dev`, `prod`, etc. |
| `dbt/profiles.yml.example` | Exemple de profil sans configuration personnelle | Un modèle à copier dans le profil dbt |
| `dbt/seeds/*.csv` | Données CSV d'entrée | De nouveaux jeux de données de référence |
| `dbt/seeds/schema.yml` | Types et documentation des seeds | Des descriptions et types de colonnes |
| `dbt/models/staging/` | Nettoyage et typage des sources | Un modèle `stg_*.sql` par source |
| `dbt/models/intermediate/` | Logique de préparation et d'enrichissement | Des modèles intermédiaires réutilisables |
| `dbt/models/marts/` | Tables finales destinées à l'analyse | Des faits, dimensions et agrégats |
| `dbt/models/*/schema.yml` | Documentation et tests des modèles | Tests `unique`, `not_null`, relations, etc. |
| `dbt/snapshots/` | Historisation des changements | De nouveaux snapshots |
| `dbt/tests/` | Tests SQL métier personnalisés | Une requête qui retourne les lignes invalides |
| `dbt/macros/` | Fonctions Jinja/SQL réutilisables | Des règles de transformation communes |
| `docs/` | Notes et commandes pédagogiques | Des explications complémentaires |
| `dbt/target/` | Artefacts générés par dbt | Ne pas modifier manuellement |
| `dbt/logs/` | Journaux d'exécution | Ne pas utiliser comme source de données |

## 🚀 Installation et lancement

### 1. Créer l'environnement Python

Depuis la racine du dépôt :

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install dbt-postgres
```

L'environnement virtuel isole dbt des autres projets Python. Le paquet
`dbt-postgres` installe dbt Core ainsi que l'adaptateur PostgreSQL.

### 2. Démarrer PostgreSQL et Adminer

```powershell
docker compose up -d
docker compose ps
```

Le service `postgres` expose PostgreSQL sur `localhost:5433` pour les outils
installés sur Windows. Le service `adminer` est disponible sur
`http://localhost:8082`.

### 3. Vérifier le profil dbt

Le profil présent dans `dbt/profiles.yml` correspond au nom déclaré dans
`dbt/dbt_project.yml`. Après avoir activé l'environnement virtuel, copiez
l'exemple puis placez-vous dans le dossier dbt :

```powershell
Copy-Item .\dbt\profiles.yml.example .\dbt\profiles.yml
cd dbt
dbt debug
```

`profiles.yml` contient les paramètres de connexion. Les identifiants présents
ici sont uniquement ceux de l'environnement Docker local ; ils ne doivent pas
être réutilisés en production.

### 4. Charger les seeds

```powershell
dbt seed
```

Cette commande transforme les CSV de `dbt/seeds/` en tables PostgreSQL dans le
schéma `raw`. Si les seeds ont été créés dans un ancien schéma, utiliser :

```powershell
dbt seed --full-refresh
```

### 5. Exécuter le pipeline

```powershell
dbt run --select staging
dbt snapshot
dbt run
```

Une séquence complète reproductible est donc :

```powershell
dbt seed --full-refresh
dbt run --select staging
dbt snapshot
dbt run
dbt test
```

## ⌨️ Commandes dbt expliquées

| Commande | Fonction |
| --- | --- |
| `dbt debug` | Vérifie la configuration et la connexion à PostgreSQL |
| `dbt seed` | Charge les fichiers CSV comme tables |
| `dbt run --select staging` | Exécute uniquement les modèles staging |
| `dbt run` | Exécute tous les modèles sélectionnables |
| `dbt snapshot` | Crée ou met à jour l'historique des conducteurs |
| `dbt test` | Exécute les tests de qualité |
| `dbt build` | Exécute les ressources avec leurs dépendances et tests |
| `dbt docs generate` | Génère la documentation et le graphe du projet |

Les variables permettent de modifier le comportement d'un modèle sans changer
son SQL :

```powershell
dbt run --select staging --vars '{"start_date": "2026-09-02"}'
```

Une date trop récente peut volontairement produire zéro ligne :

```powershell
dbt run --select staging --vars '{"start_date": "2027-09-05"}'
```

## 🔎 Consulter les données avec Adminer

Ouvrir `http://localhost:8082`, puis utiliser :

| Champ | Valeur |
| --- | --- |
| Système | PostgreSQL |
| Serveur | `postgres` |
| Utilisateur | `indrive` |
| Mot de passe | `indrive` |
| Base de données | `indrive_warehouse` |
| Port | `5432` |

Adminer se trouve dans le réseau Docker : il doit donc contacter le service
`postgres` sur son port interne `5432`, et non `localhost:5433`.

Depuis un client installé directement sur Windows, utiliser au contraire
`localhost` et le port `5433`.

## ✅ Tests de qualité

Les tests déclarés dans les fichiers `schema.yml` vérifient notamment :

- l'unicité et l'absence de valeurs nulles sur les identifiants ;
- les valeurs autorisées pour les types de véhicules ;
- l'existence des conducteurs et des zones référencés par `fact_rides`.

Les tests SQL de `dbt/tests/` vérifient des règles métier. Un test dbt réussit
lorsque sa requête ne retourne aucune ligne invalide :

- `assert_driver_ratings_in_range.sql` : note entre `0` et `5` ;
- `assert_driver_joined_dates_not_future.sql` : date d'inscription non future ;
- `assert_fact_rides_amount_not_0.sql` : montant de course non négatif.

Pour lancer tous les tests :

```powershell
dbt test
```

## 🛠️ Troubleshooting

| Symptôme | Solution |
| --- | --- |
| `port is already allocated` | Modifier le port publié dans `docker-compose.yml` et le port `profiles.yml` utilisé depuis Windows |
| `dbt debug` indique `connection refused` | Exécuter `docker compose ps` et attendre que PostgreSQL soit `Up` |
| `Could not find profile named 'indrive_analytics'` | Vérifier que `profiles.yml` contient ce nom et lancer dbt depuis le dossier `dbt` |
| `relation "raw.raw_..." does not exist` | Exécuter `dbt seed`, ou `dbt seed --full-refresh` après une modification de schéma |
| Erreur de syntaxe `accepted_values` | Utiliser la syntaxe `arguments:` et mettre à jour `dbt-postgres` |
| Connexion Adminer refusée | Utiliser `postgres` comme serveur et `5432` comme port |
| Connexion d'un client Windows refusée | Utiliser `localhost` et `5433`, pas `5432` |

## 📨 Contact

Projet partagé à des fins pédagogiques.
[LinkedIn](https://www.linkedin.com/in/oussama-inchallah/)
