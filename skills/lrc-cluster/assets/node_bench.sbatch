#!/bin/bash
#SBATCH --job-name=nodebench
#SBATCH --account=nano
#SBATCH --qos=normal
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=nodebench-%N-%j.out

# Short compute benchmark of one node: a node can pass SLURM, scratch and SMT checks and still run MD much slower.
# Submit one job per node, a suspect node and a known-good node of the same partition together (A/B):
#   sbatch -p etna_bigmem -w n0214.etna0 node_bench.sbatch
#   sbatch -p etna_bigmem -w n0200.etna0 node_bench.sbatch
# Prints "NODEBENCH node partition ranks timesteps/s". A node more than about 25% below the good node of its pair is
# degraded: add it to your excluded-nodes list. Reference rates (2026-10-06): etna 24 ranks ~10000 timesteps/s
# (n0000), etna_bigmem 32 ranks ~12700 (n0200); n0214.etna0 gave 7526 and is excluded.

set -euo pipefail
module load "${MODULE:-lammps/20250722u6-gcc}"
work=$(mktemp -d "${SLURM_SUBMIT_DIR:-$PWD}/nodebench.XXXXXX")
cd "$work"
cat > in.lj <<'EOF'
units lj
atom_style atomic
lattice sc 0.8
region box block 0 12 0 12 0 12
create_box 1 box
create_atoms 1 box
mass 1 1.0
velocity all create 1.4 72838
pair_style lj/cut 2.5
pair_coeff 1 1 1.0 1.0 2.5
neighbor 0.3 bin
timestep 0.005
fix 1 all nve
run 50000
EOF
ranks=$(( SLURM_CPUS_ON_NODE * SLURM_NNODES ))
export OMP_NUM_THREADS=1
mpirun --bind-to core --map-by core -np "$ranks" "$LMP_EXEC" -in in.lj -log bench.log -screen none
rate=$(awk '/^Performance:/ {for (i = 1; i <= NF; i++) if ($i == "timesteps/s,") print $(i - 1)}' bench.log)
echo "NODEBENCH $(hostname) $SLURM_JOB_PARTITION $ranks $rate"
cd .. && rm -r "$work"
