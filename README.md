# Iris: containerize a model and optimize it

    ./build_naive.sh        # steps 1-2
    ./measure.sh            # steps 3-5 (cold/warm build, size, layers)
    ./build_opt.sh          # step 4
    docker compose up --build   # step 6
    ./scan.sh               # step 7 (requires trivy)

Edit requirements.txt versions if they do not match your local Python.
