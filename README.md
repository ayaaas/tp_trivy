# 🌸 TP Docker : Iris — Entraînement et API d'inférence

## 📌 Présentation

Ce projet consiste à conteneuriser un modèle de Machine Learning de classification du dataset **Iris** avec Docker, puis à comparer une version naïve et une version optimisée.

L'objectif est d'étudier l'impact des optimisations sur :

- La taille des images Docker.
- Le temps de build à froid.
- Le temps de rebuild à chaud.
- L'utilisation du cache Docker.
- La sécurité des conteneurs et les vulnérabilités détectées par Trivy.

Le projet comprend également une API d'inférence avec FastAPI et une orchestration des services avec Docker Compose.

## 🎯 Objectifs

1. Conteneuriser un modèle de classification avec Docker.
2. Comparer une image naïve et une image optimisée.
3. Réduire la taille des images Docker.
4. Améliorer les temps de construction grâce au cache et aux builds multi-étapes.
5. Orchestrer l'entraînement et l'inférence avec Docker Compose.
6. Exposer le modèle via une API FastAPI.
7. Scanner les images avec Trivy et analyser les vulnérabilités.
8. Appliquer des bonnes pratiques de sécurité.

## 🧠 Modèle de Machine Learning

Le projet utilise le dataset Iris de `scikit-learn` et un modèle **Random Forest Classifier**.

Le script `train.py` entraîne le modèle et le sauvegarde dans le volume Docker partagé :

```text
/models/model.joblib
```

Le service `infer` charge ensuite ce modèle pour réaliser des prédictions via l'API.

## 📁 Structure du projet

```text
.
├── app.py                    # API FastAPI : /health et /predict
├── train.py                  # Entraînement du modèle
├── infer.py                  # Inférence
├── requirements-train.txt    # Dépendances de l'entraînement
├── requirements-infer.txt   # Dépendances de l'API
├── Dockerfile.train.naive    # Image d'entraînement naïve
├── Dockerfile.train.opt      # Image d'entraînement optimisée
├── Dockerfile.infer.naive    # Image API naïve
├── Dockerfile.infer          # Image API optimisée
├── docker-compose.yml        # Orchestration des services
├── benchmark.sh              # Benchmark de l'entraînement
├── benchmarkInf.sh           # Benchmark de l'API
├── trivy.sh                  # Analyse de sécurité
├── logstrivy/                # Résultats des scans Trivy
└── README.md
```

## 🐳 Architecture Docker

Le projet comporte deux services principaux :

- **`train`** : entraîne le modèle, le sauvegarde dans le volume `models`, puis s'arrête.
- **`infer`** : charge le modèle et démarre l'API FastAPI.

Le service `infer` démarre après la réussite du service `train`, grâce à la condition `service_completed_successfully`.

Le volume partagé permet de transmettre le modèle entre les deux services. Il est monté en lecture seule dans le conteneur d'inférence.

```text
                 Docker Compose
                       |
              +--------+--------+
              |                 |
            train              infer
              |                 |
              v                 |
       Entraînement              |
              |                 |
              v                 |
      /models/model.joblib -----+
                                |
                                v
                         API FastAPI :8000
                                |
                                v
                         Machine hôte :8080
```

## ⚙️ Version naïve et version optimisée

### Version naïve

Les Dockerfiles naïfs servent de référence pour mesurer les performances avant optimisation.

Une organisation telle que :

```dockerfile
COPY . .
RUN pip install -r requirements.txt
```

peut invalider le cache des dépendances lorsque le code source change. Docker risque alors de réinstaller les dépendances lors du rebuild.

### Version optimisée

La version optimisée applique plusieurs bonnes pratiques :

- Image de base Python Slim.
- Construction multi-étapes (*multi-stage build*).
- Environnement virtuel dédié.
- Séparation de la copie des dépendances et du code source.
- Utilisation du cache Docker.
- Désactivation du cache pip dans l'image.
- Utilisateur non-root.
- Vérification de santé avec `HEALTHCHECK`.
- Système de fichiers en lecture seule pour l'inférence.
- Option `no-new-privileges`.
- Réduction du contexte de build avec `.dockerignore`.

L'ordre optimisé des instructions est notamment :

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

Ainsi, lorsque seules les sources changent, la couche d'installation des dépendances peut être réutilisée.

## ❄️ Build à froid et 🔥 rebuild à chaud

### Build à froid

Le **build à froid** est effectué sans réutilisation du cache Docker :

```bash
docker build --no-cache ...
```

Les étapes de construction sont exécutées à nouveau, notamment l'installation des dépendances.

Cette mesure permet d'évaluer le temps nécessaire pour construire l'image sans bénéficier du cache.

### Rebuild à chaud

Le **rebuild à chaud** est réalisé après une modification du code, en conservant le cache Docker.

Si les dépendances n'ont pas changé, Docker peut réutiliser les couches correspondantes et ne reconstruire que les étapes affectées par la modification.

Le temps de rebuild dépend donc de l'organisation du Dockerfile et des couches invalidées.

## 📊 Benchmark des images d'entraînement

Le script `benchmark.sh` mesure la taille des images ainsi que les temps de build à froid et de rebuild à chaud.

### Exécution

```bash
chmod +x benchmark.sh

./benchmark.sh naive Dockerfile.train.naive
./benchmark.sh opt Dockerfile.train.opt
```

### Résultats

| Version | Taille de l'image | Build à froid | Rebuild à chaud |
|---|---:|---:|---:|
| Naïve | ~2128 Mo | ~41 s | ~44 à 52 s |
| Optimisée | À compléter | À compléter | À compléter |

Les valeurs de la version optimisée doivent être renseignées après l'exécution du benchmark correspondant.

### Interprétation

Dans la version naïve, la copie du code avant l'installation des dépendances peut provoquer une réinstallation inutile lors d'une modification des sources.

Dans la version optimisée, la séparation des dépendances et du code permet une meilleure réutilisation du cache Docker.

L'objectif est de réduire le temps de reconstruction lorsque les dépendances restent identiques.

## 📊 Benchmark de l'API d'inférence

Le script `benchmarkInf.sh` permet de comparer les images de l'API.

### Exécution

```bash
chmod +x benchmarkInf.sh
./benchmarkInf.sh
```

### Résultats

| Version | Taille de l'image | Build à froid | Rebuild à chaud |
|---|---:|---:|---:|
| Naïve | ~2,14 Go | Non mesuré | Non mesuré |
| Optimisée | 572 Mo | 131 s | 3 s |

La version optimisée présente une taille d'image nettement inférieure à celle de la version naïve.

Le rebuild à chaud de 3 secondes illustre l'intérêt du cache Docker lorsque les couches de dépendances peuvent être réutilisées.

Le build à froid de 131 secondes reste plus long, car les étapes doivent être reconstruites sans cache.

> Les temps de build dépendent de la machine, du réseau, des téléchargements et de l'état du cache. Ils constituent des mesures expérimentales, et non des performances garanties sur toutes les machines.

## 🚀 Lancer l'application

Construire les images et démarrer les services :

```bash
docker compose up -d --build
```

Consulter les logs de l'entraînement :

```bash
docker compose logs train
```

Le service doit afficher un message similaire à :

```text
Model saved to /models/model.joblib
```

Vérifier l'état des services :

```bash
docker compose ps
```

État attendu :

- `train` : `Exited (0)` après l'entraînement réussi.
- `infer` : `Up (healthy)` lorsque l'API est opérationnelle.

## 🌐 Tester l'API FastAPI

L'API écoute sur le port `8000` dans le conteneur et est exposée sur le port `8080` de la machine hôte.

### Vérification de santé

```bash
curl http://localhost:8080/health
```

Réponse attendue :

```json
{"status":"ok"}
```

### Prédiction

L'endpoint `/predict` accepte uniquement les requêtes HTTP `POST`.

```bash
curl -sS -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}'; echo
```

Réponse attendue :

```json
{"class":"setosa"}
```

### Exemples de prédiction

| Fleur | Longueur sépale | Largeur sépale | Longueur pétale | Largeur pétale | Classe attendue |
|---|---:|---:|---:|---:|---|
| Setosa | 5.1 | 3.5 | 1.4 | 0.2 | `setosa` |
| Versicolor | 6.0 | 2.9 | 4.5 | 1.5 | `versicolor` |
| Virginica | 6.5 | 3.0 | 5.5 | 2.0 | `virginica` |

### Documentation interactive

La documentation Swagger est disponible à l'adresse :

[http://localhost:8080/docs](http://localhost:8080/docs)

Pour tester une prédiction :

1. Ouvrir `/docs`.
2. Sélectionner `POST /predict`.
3. Cliquer sur **Try it out**.
4. Saisir les caractéristiques de la fleur.
5. Cliquer sur **Execute**.

> **Remarque :** ouvrir `/predict` directement dans la barre d'adresse du navigateur envoie une requête `GET`. Une réponse `405 Method Not Allowed` est normale, car cet endpoint accepte uniquement `POST`.

## 🛡️ Sécurité avec Trivy

Trivy permet d'identifier les vulnérabilités présentes dans les images Docker et d'analyser la configuration du projet.

### Exécution

```bash
chmod +x trivy.sh
./trivy.sh
```

Afficher les totaux des rapports :

```bash
grep Total logstrivy/*.log
```

Le script analyse notamment :

- `iris-infer:naive`
- `iris-infer:opt`
- La configuration Docker avec `trivy config .`

Les rapports sont enregistrés dans `logstrivy/`.

### Résultats des scans

| Image | Vulnérabilités HIGH | Vulnérabilités CRITICAL |
|---|---:|---:|
| `iris-infer:naive` | 317 + 2 | 16 |
| `iris-infer:opt` avant correction | 44 | 0 |
| `iris-infer:opt` après correction | À compléter | À compléter |

Les résultats après correction doivent être complétés à partir du dernier scan Trivy.

### Corrections appliquées

- Passage d'une image Python complète à une image Slim plus légère.
- Mise à jour des paquets système dans l'image finale.
- Mise à jour de pip pour corriger les vulnérabilités identifiées dans l'ancienne version.
- Exécution avec un utilisateur non-root.
- Utilisation d'un système de fichiers en lecture seule pour le service d'inférence.
- Activation de `no-new-privileges`.

Certaines vulnérabilités peuvent subsister lorsqu'aucun correctif n'est encore disponible dans la distribution concernée. Il convient de vérifier leur statut dans les rapports Trivy.

## 🛠️ Commandes utiles

### Construire manuellement l'image optimisée

```bash
docker build -f Dockerfile.infer -t iris-infer:opt .
```

### Reconstruire sans cache et récupérer la dernière image de base

```bash
docker build --pull --no-cache \
  -f Dockerfile.infer \
  -t iris-infer:opt .
```

### Lister les images Iris

```bash
docker image ls | grep iris
```

### Consulter les logs de l'API

```bash
docker compose logs infer --since 5m
```

### Arrêter les services

```bash
docker compose down
```

### Arrêter les services et supprimer les volumes

```bash
docker compose down -v --remove-orphans
```

## 🐞 Dépannage

| Problème | Cause possible / Solution |
|---|---|
| `Permission non accordée` sur un script | Exécuter `chmod +x script.sh` |
| `No module named 'joblib'` | Vérifier `requirements-train.txt` |
| `PermissionError` lors de l'écriture du modèle | Vérifier `MODEL_PATH` et les permissions du volume |
| `failed to read dockerfile` | Vérifier le nom du Dockerfile dans `docker-compose.yml` |
| `405 Method Not Allowed` | Utiliser `POST` pour `/predict` |
| L'API n'est pas `healthy` | Consulter `docker compose logs infer` |
| Le rebuild est trop long | Vérifier l'ordre des instructions `COPY` et `RUN` |

## 📌 Conclusion

Ce TP met en évidence l'impact des bonnes pratiques Docker sur la taille des images, les temps de construction et la sécurité.

La comparaison des versions naïve et optimisée permet d'étudier :

- la réduction de la taille des images ;
- le temps de build à froid ;
- le temps de rebuild à chaud ;
- la réutilisation du cache Docker ;
- les avantages du multi-stage build ;
- la réduction de la surface d'attaque ;
- l'analyse des vulnérabilités avec Trivy.

Les mesures obtenues sur l'image d'inférence montrent notamment une réduction de taille d'environ 2,14 Go à 572 Mo et un rebuild à chaud de 3 secondes pour la version optimisée.

Le projet constitue une mise en pratique de **Docker, Docker Compose, FastAPI, Machine Learning et sécurité des conteneurs**.
