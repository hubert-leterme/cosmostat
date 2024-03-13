## Module `pycs.astro.wl.mass_mapping`

- [ ] Class `massmap2d`: it would be better to create a separate class for each mass mapping method, inheriting from a base class implementing a `forward` or `predict` method. This way, it would be easier to write code which is shared among all mass mapping methods. E.g., `BaseMassmap2d`, `ProxWiener`, `ProxMSE`, `SparseWiener`.
- [ ] Improve intermediate methods such as `massmap2d._prepare_data`, `massmap2d._get_Wfc` and `massmap2d._noise_realizations`: instead of returning many variables, register them as instance attributes or properties for the classes `massmap2d` or `shear_data`?
- [ ] Class and variable names: should respect the Python standards.
- [ ] Class `shear_data`: put attribute declaration within the `__init__` method.