#! /usr/bin/env Python
"""
Created on Sept 10 2020

@authors: Jean-Luc Starck   
"""
# To run this experiment,the COSMOSTAT package has to be installed. Note that CosmoStat installation
# automatically installs the LENSPACK package.
# The used C++ code is in CosmoStat (to compute power spectra and spherical mass mapping)
# The python 2D mass mapping code  is in LensPack.
#
# !!!        Make sure the git folder cosmostat/build/bin is in your user path.

import os
import numpy as np
from astropy.io import fits
from scipy import ndimage
from scipy.ndimage.filters import gaussian_filter as gf
import math
import matplotlib.pyplot as plt
import astropy
import pylab
from os import remove
from subprocess import check_call
from datetime import datetime
import matplotlib
from subprocess import check_call
import readline
from mpl_toolkits.axes_grid1 import make_axes_locatable
from pysap.extensions import sparse2d
import pyqtgraph
from pyqtgraph.Qt import QtGui
import numpy as np
from numpy import linalg as LA
from sys import getsizeof
import scipy
from scipy.special import erf
from scipy import ndimage
from scipy.optimize import curve_fit

# GITHUB Cosmostat: cosmostat package
import pycs as ps
import pycs
from pycs.sparsity.sparse2d.starlet import *
from pycs.misc.cosmostat_init import *
from pycs.misc.mr_prog import *
from pycs.misc.utilHSS import *
from pycs.misc.im1d_tend import *
from pycs.misc.stats import *
from pycs.sparsity.sparse2d.dct import dct2d, idct2d
from pycs.sparsity.sparse2d.dct_inpainting import dct_inpainting
import pycs.sparsity.sparse2d.starlet
from pycs.sparsity.mrs.mrs_tools import *

import lenspack
from lenspack.image.mass_mapping import *
from lenspack.geometry.projections import gnom

from pycs.astro.wl.lenspack.image.mass_mapping import *

# from pycs.astro.wl.lenspack.geometry.projections import gnom
import footprint
from footprint import draw_footprint
from pycs.misc.im_isospec import *

# Function for drawing the data footprint
cosmos_vertices = np.load("footprint.npy")


def draw_footprint(ax, c="w", lw=1, **kwargs):
    ra, dec = cosmos_vertices.T
    ax.plot(ra, dec, c=c, lw=lw, **kwargs)


# lut='inferno'
# lut='gist_stern'
# lut='magma'

DEF_lut = "inferno"


def mp(x, a, u, ns, c):
    if ns == 0:
        ux = 1.0
    else:
        ux = (u * x) ** (-abs(ns))
    ret = np.exp(abs(a * ux)) + c
    return ret


#
#  popt, pcov = curve_fit(mp,xz,pke[1:])
#  plot(xz, mp(xz,*popt))
# https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.curve_fit.html


# This routine needs the cosmostat binary im_isospec
# it returns the estimated noisy kappa power spectrum and a polynomial
# fit to have a noise free estimation
def estimate_pk(d, M, pn):
    # Make an iterative Kaiser-Squires reconstruction with inpainting
    ksi = M.iks(d.g1, d.g2, d.mask)
    # calculate the radial power spectrum
    pksi = im_isospec(ksi.real)
    #
    # p = pksi - pn
    # pef=mr_prog(pe, prog="mr1d_filter -m8 -P -s5")
    # denoise the estimated noise theoretical powewr spectrum
    # pkef=mr_prog(pke, prog="mr1d_filter -F4 -n6 -s5 -t7 -m5 ")
    pke, pkb, Pun = M.get_theo_kappa_power_spectum(
        d, PowSpecNoise=pn, FirstFreqNoNoise=1
    )
    pen = np.copy(pke)
    xz = np.arange(pke.size)
    popt, pcov = curve_fit(mp, xz[3:], pksi[3:], method="trf")
    pf = mp(xz[1:], *popt)
    pke[1:] = pf
    pke[0] = 0.0
    pke = pke - pn
    pke[pke < 0] = 0
    # pixel window apodization,  assuming a window function of Fwhm=2 pixels,
    di = d.g1 * 0
    di[128, 128] = 1.0
    dis = M.smooth(di, sigma=0.85)  # 0.85 =
    pdis = im_isospec(dis) * 256.0**2
    pke = pke * pdis
    return pen, pke


def get_rms_error(Res, TrueSol, Mask, sigma=0):
    if sigma > 0:
        Resi = smooth2d(TrueSol - Res, sigma) * Mask
        TS = smooth2d(TrueSol, sigma) * Mask
    else:
        Resi = (TrueSol - Res) * Mask
        TS = TrueSol * Mask
    ind = np.where(Mask != 0)
    Resi[ind] = Resi[ind] - np.mean(Resi[ind])
    TS[ind] = TS[ind] - np.mean(TS[ind])
    Err = LA.norm(Resi) / LA.norm(TrueSol * Mask) * 100.0
    return Err


def make_fig_exp_wiener(lut=DEF_lut):
    # For space constraints, we provide this experiment starting from a pixelized
    # shear map, and not from the catalog.

    # Read shear data and covariance matrix
    g1 = readfits("exp_wiener_miceDSV_g1.fits")
    g2 = readfits("exp_wiener_miceDSV_g2.fits")
    Ncov = readfits("exp_wiener_miceDSV_covmat.fits")

    # Read the true convergence map and its theoretical power spectrum
    ktr = readfits("exp_wiener_miceDSV_true_convergence_map.fits")
    ps1d = readfits("exp_wiener_miceDSV_signal_powspec.fits")

    # Mass mapping class initialization
    (nx, ny) = Ncov.shape
    M = massmap2d(name="mass")
    M.init_massmap(nx, ny)
    M.DEF_niter = 200
    Inpaint = False
    M.niter_debias = 30
    M.Verbose = False

    # Read the noise power spectrum. It has been derived from
    # from the covariance matrix using 1000 realization with the command:
    #    Pn = M.get_noise_powspec(Ncov ,mask=mask,nsimu=1000, inpaint=True)
    pn = readfits("exp_wiener_miceDSV_noise_powspec.fits")

    # derive the mask from the covariance matrix
    index = np.where(Ncov < 1e2)
    mask = np.zeros((nx, ny))
    mask[index] = 1
    ind = np.where(mask != 1)
    mask[ind] = 0

    # Shear data class initialization
    d = shear_data()
    d.g1 = g1
    d.g2 = g2
    d.Ncov = Ncov
    d.mask = mask

    # make Fig. 8 of MCAlens paper
    tvilut(
        mask,
        title="DES-MICE Mask",
        lut=lut,
        filename="fig_mice_mask.png",
        vmin=0,
        vmax=1,
    )
    tvilut(
        smooth2d(ktr, 1.0) * mask,
        title="Convergence map",
        lut=lut,
        filename="fig_mice_kappa.png",
        vmin=-0.03,
        vmax=0.03,
    )
    tvilut(g1, title="g1", lut=lut, filename="fig_mice_g1.png", vmin=-0.3, vmax=0.3)
    tvilut(g2, title="g2", lut=lut, filename="fig_mice_g2.png", vmin=-0.3, vmax=0.3)

    # Wiener filtering using the theoretical power spectrum
    # exemple of wiener routine, without using the iterative prox.
    # this is not shown in the MCAlens paper
    kw, wi = M.wiener(g1, g2, ps1d, pn)

    # Proximal iterative filtering.
    ke_pwiener, kb_pwiener = M.prox_wiener_filtering(
        g1, g2, ps1d, Ncov, Pn=pn
    )  # , Pn=Pn) # ,ktr=InShearData.ktr)
    #  Proximal iterative filtering with Inpainting
    ke_inp_pwiener, kb_winp = M.prox_wiener_filtering(
        g1, g2, ps1d, Ncov, Pn=pn, Inpaint=True
    )  # , Pn=Pn) # ,ktr=InShearData.ktr)

    # make Fig. 9 of MCAlens paper
    tvilut(
        ke_pwiener,
        title="Wiener",
        lut=lut,
        filename="fig_mice_wiener.png",
        vmin=-0.004,
        vmax=0.004,
    )
    tvilut(
        ke_inp_pwiener,
        title="Inpainted Wiener",
        lut=lut,
        filename="fig_mice_inp_wiener.png",
        vmin=-0.004,
        vmax=0.004,
    )

    # agnostic wiener filtering
    # estimate a noisy power spectrum
    # pen,pke = estimate_pk(d,M,pn)
    pen = readfits("exp_wiener_miceDSV_estimated_noisy.fits")
    pke = readfits("exp_wiener_miceDSV_estimated_theoretical_pk.fits")
    kiwa, iwi = M.prox_wiener_filtering(
        g1, g2, pke, Ncov, Pn=pn
    )  # , Pn=Pn) # ,ktr=InShearData.ktr)

    plt.figure()
    s = 0
    plt.plot(pen, "blue", label="PowSpec(KappaE) - Pn")
    plt.plot(pke, color="red", label="Fit")
    plt.plot(ps1d, color="black", label="True Pk power spectrum")
    plt.legend(loc="upper right")
    plt.savefig("fig_plot_mice_pk.png")
    plt.show()

    # Example of error calculation at a give scale
    sig = 2
    print("== ERROR Sigma = ", sig)
    ks = M.gamma_to_cf_kappa(g1, g2)
    ks = ks.real
    Err_ks = get_rms_error(ks, ktr, mask, sigma=sig)
    print("   Kaiser Squires Error: ", Err_ks)
    Err_kiw = get_rms_error(ke_pwiener, ktr, mask, sigma=sig)
    print("   Iterative Wiener Error: ", Err_kiw)
    Err_kiwa = get_rms_error(kiwa, ktr, mask, sigma=sig)
    print("   Agnostic Iterative Wiener Error: ", Err_kiwa)


def make_fig_exp_ramses(lut=DEF_lut):
    D = shear_data()
    D.Ncov = readfits("exp_wiener_miceDSV_covmat.fits")
    newInputSimu = readfits("exp_ramses_true_convergence_map.fits")
    (nx, ny) = D.Ncov.shape  # assume a diagonal cov mat
    D.nx = nx
    D.ny = ny
    M = massmap2d(name="mass")
    M.init_massmap(D.nx, D.ny)
    M.DEF_niter = 100
    Bmode = True
    Inpaint = False

    index = np.where(D.Ncov < 1e2)
    D.mask = np.zeros((nx, ny))
    D.mask[index] = 1
    mask = D.mask
    n1, n2 = D.get_shear_noise()
    nxin, nyin = newInputSimu.shape
    depx = (nxin - nx) // 2
    depy = (nyin - ny) // 2
    D.ktr = newInputSimu[depx : depx + nx, depy : depy + ny]

    Minput = massmap2d(name="mass")
    Minput.init_massmap(nxin, nyin)
    (g1t, g2t) = Minput.kappa_to_gamma(newInputSimu)
    D.g1t = g1t[depx : depx + nx, depy : depy + ny]
    D.g2t = g2t[depx : depx + nx, depy : depy + ny]
    pk = im_isospec(D.ktr)
    D.ps1d = pk
    D.g1 = (D.g1t + n1) * D.mask
    D.g2 = (D.g2t + n2) * D.mask

    # Compute the MCAlens solution
    M.Verbose = False
    k1r5, k1i, k2r5, k2i = M.sparse_wiener_filtering(
        D, D.ps1d, Nsigma=5, Inpaint=Inpaint, Bmode=Bmode, InpNiter=20
    )
    # info(D.ktr-k1r5)

    # Propate noise realization to get a rms map
    run_sim1 = 0
    if run_sim1:
        Nsimu = 100
        TabSim = np.zeros([Nsimu, nx, ny])
        for i in range(Nsimu):
            print("SIMU ", i + 1)
            nk1r5, nk1i, nk2r5, nk2i5 = M.sparse_wiener_filtering(
                D, D.ps1d, Nsigma=5, Bmode=Bmode, PropagateNoise=True
            )
            TabSim[i, :, :] = nk1r5
        rms = TabSim.std(0)
        writefits("exp_ramses_mcalens_rms.fits", rms)
    else:
        rms = readfits("exp_ramses_mcalens_rms.fits")

    # make Fig.2 of MCAlens paper
    vm = 0.2
    vmin = -0.1
    tvilut(
        D.ktr * mask,
        title="True kappa map",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_ramses_kt.png",
    )
    tvilut(
        k1r5 * mask,
        title="MCAlens",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_ramses_mcalens_sig5_masked.png",
    )
    tvilut(
        (k1r5 - k2r5) * mask,
        title="MCAlens-Gaussian Component",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_ramses_mcalens_gaussian_sig5_masked.png",
    )
    tvilut(
        k2r5 * mask,
        title="MCAlens-Sparse Component",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_ramses_mcalens_sparse_sig5_masked.png",
    )

    # make Fig.3 of MCAlens paper
    tvilut(
        rms * mask,
        title="MCAlens RMS Map",
        fs=5,
        lut=lut,
        filename="fig_ramses_mcalens_rms.png",
    )
    tvilut(
        np.abs(k1r5 / rms * mask),
        title="MCAlens SNR Map",
        fs=5,
        lut=lut,
        vmax=10,
        filename="fig_ramses_mcalens_snr.png",
    )
    tvilut(
        M.WT_ActiveCoef.sum(0),
        title="Active WT Coef Mask",
        fs=5,
        lut=lut,
        filename="fig_ramses_mcalens_sig5_act_coef_support.png",
    )


def make_fig_exp_columbia(lut=DEF_lut):
    D = shear_data()
    cov_mice = readfits("exp_wiener_miceDSV_covmat.fits")
    newInputSimu = readfits("exp_colombia_true_convergence_map.fits")
    D.ktr = newInputSimu
    ResolPixel = 0.8  # the orignal image has been rebinned by a factor 2
    # MICE cov mat = 10 Euclid noise
    # mice resol = 4.5
    # Colombia resol = 0.8
    # cov_columbia = cov_mice / 10 *  area_mice / area_jia
    # ==>  4.5**2 / 0.8**2 /10 = 3.16
    ScaleToEuclidNoise = 3.16
    D.Ncov = cov_mice * ScaleToEuclidNoise
    (nx, ny) = D.Ncov.shape  # assume a diagonal cov mat
    D.nx = nx
    D.ny = ny
    index = np.where(D.Ncov < 1e2)
    D.mask = np.zeros((nx, ny))
    D.mask[index] = 1
    mask = D.mask
    n1, n2 = D.get_shear_noise()
    FirstRun = False
    if FirstRun:
        pn = M.get_noise_powspec(D.Ncov, mask=D.mask, nsimu=1000, inpaint=True)
        writefits("exp_colombia_noise_powspec.fits", pn)
        FirstRun = False
    else:
        pn = readfits("exp_colombia_noise_powspec.fits")

    M = massmap2d(name="mass")
    M.init_massmap(D.nx, D.ny)
    M.DEF_niter = 100
    Bmode = True
    Inpaint = False

    (g1t, g2t) = M.kappa_to_gamma(D.ktr)
    D.g1t = g1t
    D.g2t = g2t
    pk = im_isospec(D.ktr)
    D.ps1d = pk
    D.g1 = (D.g1t + n1) * D.mask
    D.g2 = (D.g2t + n2) * D.mask

    # Compute the MCAlens solution
    M.Verbose = False
    k1r5, k1i, k2r5, k2i = M.sparse_wiener_filtering(
        D, D.ps1d, Nsigma=5, Inpaint=Inpaint, Bmode=Bmode, InpNiter=20
    )
    # info(D.ktr-k1r5)
    kiw, iwi = M.prox_wiener_filtering(
        D.g1, D.g2, D.ps1d, D.Ncov, Inpaint=Inpaint, Pn=pn
    )  # , Pn=Pn) # ,ktr=InShearData.ktr)
    ks = M.g2k(D.g1, D.g2)
    Sigma2Fwhm = 2.355
    sig = 2.0
    ks2 = smooth2d(ks, 2.0) * mask  # Resol = ResolPixel * Sigma2Fwhm * sig = 3.8 amin

    # Propate noise realization to get a rms map
    run_sim1 = 0
    if run_sim1:
        Nsimu = 100
        TabSim = np.zeros([Nsimu, nx, ny])
        for i in range(Nsimu):
            print("SIMU ", i + 1)
            nk1r5, nk1i, nk2r5, nk2i5 = M.sparse_wiener_filtering(
                D, D.ps1d, Nsigma=5, Bmode=Bmode, PropagateNoise=True
            )
            TabSim[i, :, :] = nk1r5
        rms = TabSim.std(0)
        writefits("exp_columbia_mcalens_rms.fits", rms)
    else:
        rms = readfits("exp_columbia_mcalens_rms.fits")

    vm = 0.1
    vmin = -0.1
    # make Fig.5 of MCAlens paper
    tvilut(
        D.ktr * mask,
        title="True kappa map",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_jia_kt.png",
    )
    tvilut(
        kiw * mask,
        title="Wiener",
        fs=5,
        vmin=-0.02,
        vmax=0.02,
        lut=lut,
        filename="fig_jia_wiener.png",
    )
    tvilut(
        ks2,
        title="KS (Fwhm=3.8 arcmin)",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_jia_ks2.png",
    )

    tvilut(
        k1r5 * mask,
        title="MCAlens (lambda=5)",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_jia_mcalens_sig5.png",
    )
    tvilut(
        (k1r5 - k2r5) * mask,
        title="MCAlens-Gaussian Component (lambda=5)",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_jia_mcalens_xw_sig5.png",
    )
    tvilut(
        k2r5 * mask,
        title="MCAlens-Sparse Component (lambda=5)",
        fs=5,
        vmin=vmin,
        vmax=vm,
        lut=lut,
        filename="fig_jia_mcalens_xs_sig5.png",
    )

    tvilut(
        rms * mask,
        title="MCAlens RMS Map",
        fs=5,
        lut=lut,
        filename="fig_jia_mcalens_rms.png",
    )
    tvilut(
        np.abs(k1r5 / rms * mask),
        title="MCAlens SNR Map",
        fs=5,
        lut=lut,
        filename="fig_jia_mcalens_snr.png",
    )
    tvilut(
        M.WT_ActiveCoef.sum(0),
        title="Active WT Coef Mask",
        lut=lut,
        fs=5,
        filename="fig_jia_mcalens_sig5_act_coef_support.png",
    )


# Routine for COSMOS EXPERIMENT
def get_extend_radec():
    ra0, dec0 = (
        150.11,
        2.24,
    )  # from cosmos.astro.caltech.edu (could also just use the medians of positions)
    proj = gnom.projector(ra0, dec0)
    dx = np.deg2rad(1.5) / 2.0  # 1.5 degrees across
    dy = dx
    extent_xy = [-dx, dx, -dy, dy]
    ra_min, dec_min = proj.xy2radec(-dx, -dy)
    ra_max, dec_max = proj.xy2radec(dx, dy)
    extent_radec = [ra_min, ra_max, dec_min, dec_max]
    return extent_radec


def tvradec(
    ima,
    title="ima",
    vmin=None,
    vmax=None,
    smooth=None,
    xclus=False,
    mtext=False,
    m500min=0,
    zmin=0.3,
    zmax=1,
    ztext=False,
    lut=DEF_lut,
    filename=None,
    extent_radec=None,
):
    if extent_radec is None:
        extent_radec = get_extend_radec()

    fs = 18  # fontsize
    fig, ax = plt.subplots(1, 1, figsize=(10, 8))
    # Kappa map
    if smooth is None:
        imaS = ima
    else:
        imaS = gf(ima, smooth)
    img = ax.imshow(
        imaS, origin="lower", cmap=lut, vmin=vmin, vmax=vmax, extent=extent_radec
    )
    draw_footprint(ax)

    # Xray clusters
    if xclus:
        xclusters = np.loadtxt("xray.txt")
        highz = (xclusters[:, 6] >= zmin) & (xclusters[:, 6] <= zmax)
        for cluster in xclusters[highz]:
            ra_cl, dec_cl, z_cl = cluster[1], cluster[2], cluster[6]
            m500 = cluster[7]
            if m500 > m500min:
                ax.scatter(ra_cl, dec_cl, c="w", s=12)
                if ztext:
                    ax.text(
                        ra_cl + 0.03,
                        dec_cl + 0.02,
                        "{:.2f}".format(z_cl),
                        fontsize=8,
                        c="w",
                    )
                if mtext:
                    ax.text(
                        ra_cl + 0.03,
                        dec_cl - 0.02,
                        "{:.2f}".format(m500),
                        fontsize=8,
                        c="w",
                    )

    # Clean up and decorate
    ax.set_aspect("equal")
    ax.set_xlim(ax.get_xlim()[::-1])
    ax.set_title(title, fontsize=fs)
    ax.set_xlabel("RA [deg]", fontsize=fs)
    ax.set_ylabel("Dec [deg]", fontsize=fs)
    fig.colorbar(img, ax=ax)
    if filename is not None:
        plt.savefig(filename)


def tvglimpse(
    mask=None,
    vmin=0,
    vmax=0.04,
    xclus=False,
    lut=DEF_lut,
    mtext=False,
    m500min=0,
    zmin=0.3,
    zmax=1,
    ztext=False,
    filename=None,
):
    hdulist = fits.open("cosmos_bright_lambda3.0_niter1000_debias1000.fits")
    kappa, ra, dec = [hdu.data for hdu in hdulist]
    if mask is not None:
        kappa *= mask

    fs = 18  # fontsize

    # Determine glimpse RA/Dec extent (not perfect !)
    ra_min_gl = np.mean([ra[0][0], ra[-1][0]])
    ra_max_gl = np.mean([ra[0][-1], ra[-1][-1]])
    dec_min_gl = np.mean([dec[0][0], dec[0][-1]])
    dec_max_gl = np.mean([dec[-1][0], dec[-1][-1]])
    extent_glimpse = [ra_min_gl, ra_max_gl, dec_min_gl, dec_max_gl]
    # extent_glimpse = [149.04680898212678,151.17319101787328,1.1774193776516106,3.3018101267642783]

    fig, ax = plt.subplots(1, 1, figsize=(10, 8))
    img = ax.imshow(kappa, origin="lower", cmap=lut, vmax=0.1, extent=extent_glimpse)
    draw_footprint(ax)

    # Plot xray clusters
    if xclus:
        xclusters = np.loadtxt("xray.txt")
        highz = (xclusters[:, 6] >= zmin) & (xclusters[:, 6] <= zmax)

        for cluster in xclusters[highz]:
            ra_cl, dec_cl, z_cl = cluster[1], cluster[2], cluster[6]
            m500 = cluster[7]
            if m500 > m500min:
                ax.scatter(ra_cl, dec_cl, c="w", s=12)
                if ztext:
                    ax.text(
                        ra_cl + 0.03,
                        dec_cl + 0.02,
                        "{:.2f}".format(z_cl),
                        fontsize=8,
                        c="w",
                    )
                if mtext:
                    ax.text(
                        ra_cl + 0.03,
                        dec_cl - 0.02,
                        "{:.2f}".format(m500),
                        fontsize=8,
                        c="w",
                    )

    # Clean up and decorate
    extent_radec = get_extend_radec()
    ax.set_aspect("equal")
    ax.set_title("Glimpse2D ($\lambda=3.0$)", fontsize=fs)
    ax.set_xlabel("RA [deg]", fontsize=fs)
    ax.set_ylabel("Dec [deg]", fontsize=fs)
    # ax.set_xlim(149.25, 151)
    # ax.set_ylim(1.375, 3.125)
    ax.set_xlim(extent_radec[:2])
    ax.set_ylim(extent_radec[2:])
    ax.set_xlim(ax.get_xlim()[::-1])
    fig.colorbar(img, ax=ax)
    if filename is not None:
        plt.savefig(filename)


def make_fig_exp_cosmos(lut=DEF_lut, WriteRes=False):
    # Using bright galaxy catalog, we got these 2 binned shear images
    e1map = readfits("cosmos_g1.fits")
    e2map = readfits("cosmos_g2.fits")
    galmap = readfits("cosmos_countmap.fits")
    ps1d = readfits("cosmos_estimated_signal_powspec.fits")
    pn = readfits("cosmos_estimated_noise_powspec.fits")

    # Kaiser-Squires inversion
    # kE, kB = ks93(e1map, e2map)

    D = shear_data()
    D.g1 = e1map
    D.g2 = e2map
    SigmaNoise = 0.28
    (nx, ny) = e1map.shape  # assume a diagonal cov mat
    ind = np.where(galmap > 0)
    D.mask = np.zeros((nx, ny))
    D.mask[ind] = 1
    Ncov = np.zeros((nx, ny))
    Ncov[ind] = 2.0 * SigmaNoise**2 / galmap[ind]
    Ncov[Ncov == 0] = 1e9
    D.Ncov = Ncov
    D.nx = nx
    D.ny = ny

    FNsuf = "_db"
    M = massmap2d(name="mass")
    M.init_massmap(D.nx, D.ny)
    M.DEF_niter = 100
    Inpaint = False
    Bmode = True
    g1 = D.g1
    g2 = D.g2
    ks = M.g2k(g1, g2)
    ks2 = M.smooth(ks, sigma=2)
    kiw, iwi = M.prox_wiener_filtering(
        D.g1, D.g2, ps1d, D.Ncov, Inpaint=Inpaint, Pn=pn
    )  # , Pn=Pn) # ,ktr=InShearData.ktr)

    k1r5, k1i5, k2r5, k2i = M.sparse_wiener_filtering(
        D, ps1d, Nsigma=5, Inpaint=Inpaint, Bmode=Bmode, ktr=None
    )

    vmin = -0.03
    vmax = 0.1
    zmax = 0.99
    m500min = 3
    mtext = False  # overplot x-clusters M500
    ztext = True  # overplot x-clusters redshift
    Sigma2Fwhm = 2.355
    smooth = 1.2 / Sigma2Fwhm  # resolution in Massey 07 paper
    xclus = True  # True to overplot x-clusters
    FN5 = "fig_cosmos" + FNsuf + "_mcalens_5sigma.png"
    m = D.mask

    FN = "fig_cosmos" + FNsuf + "_" + "galmap" + ".png"
    tvradec(galmap, "Galaxy number count", lut=lut, filename=FN)
    FNW = "fig_cosmos" + FNsuf + "_wiener.png"
    tvradec(
        kiw * m,
        title="Wiener",
        xclus=xclus,
        lut=lut,
        mtext=mtext,
        m500min=m500min,
        vmin=-0.01,
        vmax=0.02,
        zmax=zmax,
        smooth=smooth,
        ztext=ztext,
        filename=FNW,
    )
    FN = "fig_cosmos" + FNsuf + "_ks2.png"
    s2 = 1.2 / Sigma2Fwhm * 2.0
    tvradec(
        ks2,
        title="KS (FWHM=2.4arcmin)",
        xclus=xclus,
        lut=lut,
        mtext=mtext,
        m500min=m500min,
        vmin=vmin,
        vmax=vmax,
        zmax=zmax,
        smooth=s2,
        ztext=ztext,
        filename=FN,
    )
    FNG = "fig_cosmos" + FNsuf + "_glimpse.png"
    tvglimpse(
        mask=m,
        vmin=vmin,
        vmax=vmax,
        xclus=xclus,
        lut=lut,
        mtext=mtext,
        m500min=m500min,
        zmax=zmax,
        ztext=ztext,
        filename=FNG,
    )
    tvradec(
        k1r5 * m,
        title="MCALens (lambda=5)",
        xclus=xclus,
        lut=lut,
        mtext=mtext,
        m500min=m500min,
        vmin=vmin,
        vmax=vmax,
        zmax=zmax,
        smooth=smooth,
        ztext=ztext,
        filename=FN5,
    )
    # FN5="fig_cosmos"+FNsuf+"_mcalens_5sigma_xs.png"
    # tvradec(k2r5*m, title='MCALens-Gaussian Component  (lambda=5)',xclus=xclus,lut=lut, mtext=mtext,m500min=m500min, vmin=vmin,vmax=vmax,zmax=zmax, smooth=smooth,ztext=ztext,filename=FN5)
    # FN5="fig_cosmos"+FNsuf+"_mcalens_5sigma_xw.png"
    # tvradec((k1r5-k2r5)*m, title='MCALens-Gaussian Component (lambda=5)',xclus=xclus,lut=lut, mtext=mtext,m500min=m500min, vmin=vmin,vmax=vmax,zmax=zmax, smooth=smooth,ztext=ztext,filename=FN5)
    FN = "fig_cosmos" + FNsuf + "_mcalens_5sigma_bmode.png"
    tvradec(
        k1i5,
        title="B-mode (lambda=5)",
        xclus=xclus,
        lut=lut,
        mtext=mtext,
        m500min=m500min,
        vmin=vmin,
        vmax=vmax,
        zmax=zmax,
        smooth=smooth,
        ztext=ztext,
        filename=FN,
    )


def make_fig_exp_sphere(lut=DEF_lut):
    dpi = 100
    k = mrs_read("exp_sphere_mice_kappa.fits")
    nside = hp.get_nside(k)
    print("Nside = ", nside)
    print("Resol pixel (arcmin)= ", hp.nside2resol(nside, arcmin=True))

    g1 = mrs_read("exp_sphere_mice_g1_noisy.fits")
    g2 = mrs_read("exp_sphere_mice_g2_noisy.fits")

    # k0p5 = hp.smoothing(k, sigma=0.5/360. * (np.pi*2),pol=False)
    k1 = hp.smoothing(k, sigma=1.0 / 360.0 * (np.pi * 2), pol=False)
    # k2 = hp.smoothing(k, sigma=2./360. * (np.pi*2),pol=False)
    k3 = hp.smoothing(k, sigma=3.0 / 360.0 * (np.pi * 2), pol=False)

    hp.mollview(k1, title="Simulated kappa map (1 degree)", cmap=lut)
    plt.savefig("fig_sphere_mice_input_1deg.png", dpi=dpi)
    hp.mollview(k3, title="Simulated kappa map (3 degrees)", cmap=lut)
    plt.savefig("fig_sphere_mice_input_3deg.png", dpi=dpi)

    # hp.mollview(k0p5,title='Simulated kappa map (0.5 degree)', cmap=lut)
    # plt.savefig('fig_sphere_mice_input_0.5deg.png', dpi=dpi)
    # hp.mollview(k2,title='Simulated kappa map (2 degrees)', cmap=lut)
    # plt.savefig('fig_sphere_mice_input_2deg.png', dpi=dpi)

    FirstRun = 0
    if FirstRun:
        cmd = "wls_mcalens -F2 -i200 -N exp_sphere_covmat.fits -v -s5 -n5  -m4 -S exp_sphere_mice_kappa_cl.fits exp_sphere_mice_g1_noisy.fits exp_sphere_mice_g2_noisy.fits  res_mice_200"
        args = shlex.split(cmd)
        call(args)
    x1 = mrs_read("res_mice_200_e.fits")
    xs1 = mrs_read("res_mice_200_sparse_e.fits")

    x11 = hp.smoothing(xs1, sigma=1.0 / 360.0 * (np.pi * 2), pol=False)

    hp.mollview(x11, title="MCALens: sparse component (1 degree)", cmap=lut)
    plt.savefig("fig_sphere_mice_mcalens_sparse.png", dpi=dpi)

    hp.mollview(x1 - xs1, title="MCALens: Wiener component", cmap=lut)
    plt.savefig("fig_sphere_mice_mcalens_wiener.png", dpi=dpi)


def make_all_figs(lut="magma"):
    make_fig_exp_wiener(lut=lut)
    make_fig_exp_columbia(lut=lut)
    make_fig_exp_ramses(lut=lut)
    make_fig_exp_cosmos(lut=lut)
    make_fig_exp_sphere(lut=lut)


lut = DEF_lut
make_all_figs(lut=lut)
