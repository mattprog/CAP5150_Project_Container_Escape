for profile in baseline user-isolation capabilities seccomp hardened; do
  ./tests/run-report.sh "$profile"
done
