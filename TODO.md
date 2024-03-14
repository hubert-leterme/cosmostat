## Module `pycs.astro.wl.mass_mapping`

- [x] Remove `for` loops wherever possible
- [x] Vectorize mass mapping methods: operate on stacks of images rather than single images.
- [ ] Class `massmap2d`: it would be better to create a separate class for each mass mapping method, inheriting from a base class implementing a `forward` or `predict` method. This way, it would be easier to write code which is shared among all mass mapping methods. E.g., `BaseMassmap2d`, `ProxWiener`, `ProxMSE`, `SparseWiener`.
- [ ] Improve intermediate methods such as `massmap2d._prepare_data`, `massmap2d._get_Wfc` and `massmap2d._noise_realizations`: instead of returning many variables, register them as instance attributes or properties for the classes `massmap2d` or `shear_data`?
- [ ] Class and variable names: should respect the Python standards.
- [ ] Classes `shear_data`, `massmap2d` and `starlet2d`: put attribute declaration within the `__init__` methods. Moreover, merge `init_massmap` and `init_starlet` into the respective `__init__` methods.
- [ ] Are the attributes `nx` and `ny` really necessary for `massmap2d`? What about `starlet2d`?
- [ ] Remove argument `ind` from `_prepare_data` (remove `np.where` wherever possible; useless most of the time)
- [x] Improve `mask = (Ncv < 1e2).astype(int)` (could be placed before)
- [x] Bug correction in `gamma_to_cf_kappa` (raise `NotImplementedError`, to be done later if necessary)
- [x] Optimize `kappa_to_gamma`, `gamma_to_cf_kappa`, `gamma_to_kappa`, `H_operator_eb2g` and `H_adjoint_g2eb`: work on complex arrays
- [ ] Remove redundancy with the above methods

## Module `pycs.sparsity.sparse2d.starlet`

- [ ] Class `MRStarlet`: modify methods `transform` and `recons` in order them to operate on stacks of images (n-D tensors). Modify the C implementation, or implement them in PyTorch to take advantage of GPU acceleration. As a workaround, I used `np.vectorize` to achieve the same results, but computational efficiency could be widely improved.

## Package `pycs`

- [ ] Work with `dtype = np.float32` and `np.complex64`, or `dtype = np.float64` and `np.complex128`? Harmonize code.
- [ ] Remove `np.copy()` wherever possible (useless memory usage)