# Software, modules, and GPUs on Lawrencium

## Modules

- Lmod. Group modulefiles: `/global/home/groups-sw/nano/modulefiles/rocky-8.x86_64/` (on the default MODULEPATH). Write group modulefiles there.
- Group software installs: `/global/home/groups-sw/nano/software/rocky-8.x86_64/<app>/`, shared with the whole nano group (many members link it as `~/software`).

## Python environments

- Keep project Python envs in your own miniforge (`$HOME/miniforge3/envs/<env>`). For MD and electrolyte work use Python 3.12 with numpy, MDAnalysis, SciPy, ASE, PACKMOL, pytest and editable installs of mdinterface and comodino.
- `/usr/bin/python3` is Python 3.6. Anything run by systemd timers or other non-login contexts gets that interpreter unless it calls an env's `python` by absolute path.
- Conda envs have no `bin/activate`; prepend its `bin/` to PATH (or `source ~/miniforge3/etc/profile.d/conda.sh && conda activate <env>`) so `shutil.which("packmol")` resolves; current mdinterface installs the PACKMOL executable from PyPI into the env's `bin/`, so an unactivated shell still cannot find it.
- Editable installs follow the checkout live: a `git pull` or branch switch changes the code every running job imports. Campaigns pin a worktree instead (see `comodino-campaigns`).
- After pulling an editable install from git, refresh it (`pip install -e <checkout>`) so the recorded version stops being stale in provenance files (`build.json`).

## Building and installing software

- Build on compute nodes via sbatch (a LAMMPS rebuild takes about 15 minutes on 24 cores).
- Install into `install/<version>-<variant>/`. The cmake presets (`custom_*_u6.cmake`) and build scripts (`build_22Jul2025u6_*.sh`) sit in the app directory next to the sources, e.g. `/global/home/groups-sw/nano/software/rocky-8.x86_64/lammps/`. Add the modulefile to the group modulefiles directory.
- Record what was built, from what commit or tarball, and the modulefile name in the project `AGENTS.md`.

## GPUs

- `etna_gpu` V100 nodes (free, `--account=nano --gres=gpu:V100:N`, N at most 2): `nvidia-smi` works on n0238 (Tesla V100-SXM2-16GB, driver 580.178.04, sm_70). The earlier broken-driver report no longer holds; confirm with a short `nvidia-smi` job if a node misbehaves.
- `etna_gpu` K80 nodes: all down or drained, and sm_37 is below the CUDA 12 minimum anyway. Do not target them.
- Paid GPU partitions (`ac_nanotheory`, ask first): es0 RTX 2080 Ti (sm_75), es1 A40/A100/V100/RTX 8000 (sm_86/80/70/75), es2 H100/H200 (sm_90). A CUDA build runs only on the architectures it was compiled for; `lammps/20250722u6-gpu` covers sm_50/70/75/80/86, which leaves out es2.

## Jupyter on Open OnDemand

https://lrc-ondemand.lbl.gov -> Interactive Apps -> Jupyter Notebook (compute mode) runs notebooks on a compute node. A conda env appears there once it has a registered kernel: `~/miniforge3/envs/ENV/bin/python -m pip install ipykernel && ~/miniforge3/envs/ENV/bin/python -m ipykernel install --user --name=ENV`, then pick that kernel in the notebook. The older instructions that load `anaconda3/2024.02-1-11.4` are obsolete: that module no longer exists.
