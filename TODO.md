## Module `pycs.astro.wl.mass_mapping`

- [x] Remove `for` loops wherever possible
- [x] Vectorize mass mapping methods: operate on stacks of images rather than single images.
- [ ] Class `massmap2d`: it would be better to create a separate class for each mass mapping method, inheriting from a base class implementing a `forward` or `predict` method. This way, it would be easier to write code which is shared among all mass mapping methods. E.g., `BaseMassmap2d`, `ProxWiener`, `ProxMSE`, `SparseWiener`.
- [ ] Improve intermediate methods such as `massmap2d._prepare_data`, `massmap2d._get_Wfc` and `massmap2d._noise_realizations`: instead of returning many variables, register them as instance attributes or properties for the classes `massmap2d` or `shear_data`?
- [ ] Class and variable names: should respect the Python standards.
- [ ] Class `shear_data`: put attribute declaration within the `__init__` method.
- [ ] Remove argument `ind` from `_prepare_data` (remove `np.where` wherever possible; useless most of the time)
- [ ] Improve `mask = (Ncv < 1e2).astype(int)` (could be placed before)
- [ ] Simplify `gamma_to_cf_kappa` (remove `init_starlet`)
- [ ] Redundancy with `H_operator_eb2g` and `H_adjoint_g2eb`, with respect to `gamma_to_kappa` and `kappa_to_gamma`?
- [ ] Optimize `H_operator_eb2g` and `H_adjoint_g2eb`: work on complex arrays

## Module `pycs.sparsity.sparse2d.starlet`

- [ ] Class `MRStarlet`: modify methods `transform` and `recons` in order them to operate on stacks of images (n-D tensors). Modify the C implementation, or implement them in PyTorch to take advantage of GPU acceleration. As a workaround, I used `np.vectorize` to achieve the same results, but computational efficiency could be widely improved.

## Package `pycs`

- [ ] Work with `dtype = np.float32` and `np.complex64`, or `dtype = np.float64` and `np.complex128`? Harmonize code.
- [ ] Remove `np.copy()` wherever possible (useless memory usage)