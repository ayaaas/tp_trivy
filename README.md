# TP Docker : Iris (entraînement + API d'inférence)

Ce projet conteneurise un petit modèle de classification d'iris (scikit-learn) avec Docker, en comparant une version **naïve** et une version **optimisée** (taille, vitesse de build, sécurité).

## Objectifs

1. **Optimiser les images Docker** : image slim, ordre des couches, multi-étapes, `.dockerignore`.
2. **Orchestrer avec Docker Compose** : un service `train` qui entraîne le modèle, un service `infer` qui le sert via une API.
3. **Sécuriser avec Trivy** : scanner les images, corriger des vulnérabilités, comparer avant/après.

## Structure du projet

```
.
├── app.py                    # API FastAPI (/health, /predict)
├── train.py                  # Entraînement du modèle (RandomForest)
├── infer.py
├── requirements-train.txt    # Dépendances de l'entraînement
├── requirements-infer.txt    # Dépendances de l'API
├── Dockerfile.train.naive    # Image d'entraînement non optimisée
├── Dockerfile.train.opt      # Image d'entraînement optimisée (multi-étapes)
├── Dockerfile.infer.naive    # Image API non optimisée
├── Dockerfile.infer          # Image API optimisée (multi-étapes, non-root, healthcheck)
├── docker-compose.yml        # Services train + infer, volume partagé
├── benchmark.sh              # Benchmark des images d'entraînement
├── benchmarkInf.sh           # Benchmark de l'image API
├── trivy.sh                  # Scans de sécurité
└── logstrivy/                # Résultats des scans Trivy
```

## Lancer l'application

```bash
docker compose up -d --build
docker compose logs train      # doit afficher "Model saved to /models/model.joblib"
docker compose ps              # infer = Up (healthy), train = Exited (0)
```

Fonctionnement :

- `train` entraîne le modèle et l'écrit dans le volume `models` (variable `MODEL_PATH=/models/model.joblib`), puis s'arrête.
- `infer` démarre une fois `train` terminé avec succès (`service_completed_successfully`), lit le modèle en lecture seule et expose l'API.
- L'API écoute sur le port **8000** dans le conteneur, publié sur le port **8080** de la machine.

Pour tout arrêter et supprimer le volume :

```bash
docker compose down -v --remove-orphans
```

## Tester l'API

Santé :

```bash
curl localhost:8080/health
```

Réponse attendue : `{"status":"ok"}`

Prédiction (méthode **POST** uniquement) :

```bash
curl -sS -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}'; echo
```

Réponse attendue : `{"class":"setosa"}`

Exemples pour les autres classes :

| Fleur | sepal_length | sepal_width | petal_length | petal_width | Résultat |
|---|---|---|---|---|---|
| Setosa | 5.1 | 3.5 | 1.4 | 0.2 | setosa |
| Versicolor | 6.0 | 2.9 | 4.5 | 1.5 | versicolor |
| Virginica | 6.5 | 3.0 | 5.5 | 2.0 | virginica |

Documentation interactive : <http://localhost:8080/docs> (cliquer sur `POST /predict`, puis **Try it out** et **Execute**).

> **Remarque :** appeler `/predict` depuis la barre d'adresse d'un navigateur envoie une requête **GET** et renvoie `405 Method Not Allowed`. C'est le comportement attendu : la route n'accepte que POST.

## Optimisations appliquées

| Technique | Effet |
|---|---|
| Image de base `python:3.12-slim` au lieu de `python:3.11` complète | Image beaucoup plus petite, moins de paquets donc moins de vulnérabilités |
| Build multi-étapes (builder + image finale, venv copié) | Aucun résidu de build dans l'image finale |
| `COPY requirements*.txt` puis `pip install`, **puis** `COPY` du code | Les dépendances restent en cache quand seul le code change |
| `PIP_NO_CACHE_DIR=1` | Pas de cache pip dans l'image |
| Utilisateur non-root (`app`, UID 10001) | Réduction de la surface d'attaque |
| `HEALTHCHECK` sur `/health` | Compose connaît l'état réel de l'API |
| `read_only: true`, `no-new-privileges` (service `infer`) | Durcissement du conteneur |
| `.dockerignore` | Contexte de build réduit |

## Benchmark

Lancer :

```bash
chmod +x benchmark.sh
./benchmark.sh naive Dockerfile.train.naive
./benchmark.sh opt Dockerfile.train.opt
```

Le script mesure la taille de l'image, le **build à froid** (`--no-cache`, tout est refait) et le **rebuild à chaud** (après modification de `train.py`, avec le cache).

### Image d'entraînement

| | Taille | Build à froid | Rebuild à chaud |
|---|---|---|---|
| naive | 2128 Mo | ~41 s | ~44 à 52 s |
| opt | _à compléter_ | _à compléter_ | _à compléter_ |

Dans la version naïve, `COPY . .` précède `pip install` : toute modification du code invalide le cache et réinstalle toutes les dépendances. Dans la version optimisée, seule la dernière couche est reconstruite.

### Image API

| | Taille | Build à froid | Rebuild à chaud |
|---|---|---|---|
| naive | ~2,14 Go | non mesuré | non mesuré |
| opt | 572 Mo | 131 s | 3 s |

## Sécurité avec Trivy

```bash
chmod +x trivy.sh
./trivy.sh
grep Total logstrivy/*.log
```

Le script scanne `iris-infer:naive`, `iris-infer:opt` et la configuration (`trivy config .`). Les résultats sont dans `logstrivy/`.

### Résultats

| Image | HIGH | CRITICAL |
|---|---|---|
| `iris-infer:naive` (Debian + Python) | 317 + 2 | **16** |
| `iris-infer:opt` (avant correction) | 44 | 0 |
| `iris-infer:opt` (après correction) | _à compléter_ | _à compléter_ |

### Corrections appliquées

- **Image de base plus petite et à jour** : passage de `python:3.11` à `python:3.12-slim`, ce qui supprime la quasi-totalité des vulnérabilités critiques de l'image naïve.
- **Mise à jour des paquets système** dans l'image finale : `apt-get update && apt-get upgrade -y`.
- **Mise à jour de pip** (5 CVE de sévérité MEDIUM dans `pip 25.0.1`, corrigées en 26.x) : `/usr/local/bin/pip install --upgrade pip`.

Certaines vulnérabilités Debian restantes sont marquées `fix_deferred` ou `affected` : aucun correctif n'est encore publié par Debian, elles ne peuvent donc pas être corrigées côté image.

## Commandes utiles

```bash
# Construire une image à la main
docker build -f Dockerfile.infer -t iris-infer:opt .

# Reconstruire sans cache et récupérer la dernière base
docker build --pull --no-cache -f Dockerfile.infer -t iris-infer:opt .

# Voir les requêtes reçues par l'API
docker compose logs infer --since 5m | grep predict

# Lister les images
docker image ls | grep iris
```

## Dépannage

| Problème | Cause et solution |
|---|---|
| `Permission non accordée` sur un `.sh` | `chmod +x script.sh` |
| `No module named 'joblib'` dans `train` | `requirements-train.txt` est vide ou incomplet |
| `PermissionError: 'models'` dans `train` | `train.py` doit lire `MODEL_PATH` (`os.getenv("MODEL_PATH", "models/iris.joblib")`) |
| `failed to read dockerfile` | Le nom du Dockerfile dans `docker-compose.yml` est incorrect |
| `405 Method Not Allowed` | Requête GET sur `/predict` : utiliser POST |
