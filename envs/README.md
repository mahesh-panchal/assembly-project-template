## Envs folder

A place to store environment definition files.

### Creating the Nextflow environment for all.

> [!IMPORTANT]
> We have changed from using Conda to using Pixi. This information remains here solely for
> historical information. See the `pixi.toml` for current project environment.

```bash
conda env create --prefix /proj/snic2021-6-194/conda/nextflow-env -f /path/to/conda-nextflow-env.yml
```
