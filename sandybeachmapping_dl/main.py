##################################################
# MAPPING SANDY BEACHES USING DEEP LEARNING
# Author: Suk Yee Yong
##################################################

from collections import defaultdict
from datetime import timedelta
from omegaconf import DictConfig, OmegaConf
from pathlib import Path
from sklearn.model_selection import train_test_split
from tqdm import tqdm
from torch.utils.data import DataLoader
import glob
import hydra
import logging
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
import segmentation_models_pytorch as smp
import time
import torch

from sandybeachmapping_dl.lib.beachdataset import BeachDataset
import sandybeachmapping_dl.lib.plot_utils as plot_utils
import sandybeachmapping_dl.lib.file_utils as file_utils
log = logging.getLogger(__name__)


@hydra.main(version_base=None, config_path='../config', config_name='config.yaml')
def main(cfg: DictConfig) -> None:
    file_utils.set_seed(cfg.seed)
    device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')
    logdir_exp = Path(hydra.core.hydra_config.HydraConfig.get()['runtime']['output_dir'])
    t0 = time.time()
    
    # Define paths
    data_dir = Path(cfg.data_dir).expanduser()
    image_subdir = Path(data_dir, cfg.image_subdir)
    mask_subdir = None if cfg.mask_subdir is None else Path(data_dir, cfg.mask_subdir)
    # Create output directory
    maskpred_subdir = Path(logdir_exp, cfg.maskpred_subdir+('_all' if cfg.test_imageset=='all' else ''))
    Path(maskpred_subdir).mkdir(parents=True, exist_ok=True)
    if cfg.model_path is None:
        cfg.model_path = str(Path(logdir_exp, 'model.pth'))
    cfg.fid_osmid_path = Path(cfg.fid_osmid_path).expanduser()
    cfg.profmask_path = Path(cfg.profmask_path).expanduser()
    assert cfg.profmask_path.is_file(), f"Example mask file {cfg.profmask_path} not found! Require `cfg.profmask_path` to get profile to save GeoTiff masks."
    
    # Get list of images
    list_image = glob.glob1(image_subdir, '*.tif')
    image_prefix = list_image[0].rpartition('.')[0].rpartition('_')[0]
    if cfg.train or ('mask' in cfg.test_imageset):
        assert mask_subdir is not None, "Require `cfg.mask_subdir` if `cfg.train=True` or `cfg.test_imageset='mask'`."
        assert Path(cfg.fid_osmid_path).exists(), "Require `cfg.fid_osmid_path` if `cfg.train=True` or `cfg.test_imageset='mask'`."
        # Select only those with known masks
        fid_osmid = pd.read_csv(Path(cfg.fid_osmid_path))
        fid_osmid = fid_osmid.drop_duplicates(subset=['FID']) # Remove duplicates
        # Split by FID
        fid_train, fid_test = train_test_split(fid_osmid['FID'].to_numpy(), test_size=cfg.frac_test, random_state=cfg.seed)
        fid_train, fid_valid = train_test_split(fid_train, test_size=cfg.frac_test/(1-cfg.frac_test), random_state=cfg.seed)
        list_image_train = [f"{image_prefix}_{fid}.tif" for fid in fid_train]
        list_image_valid = [f"{image_prefix}_{fid}.tif" for fid in fid_valid]
        list_image_test = [f"{image_prefix}_{fid}.tif" for fid in fid_test]
    if cfg.test_imageset == 'mask+nomask':
        list_image_nomask = list(set(list_image) - set([f"{image_prefix}_{fid}.tif" for fid in fid_osmid['FID'].to_numpy()]))
        list_image_test = list(set().union(list_image_test, list_image_nomask))
    elif cfg.test_imageset == 'all':
        list_image_test = list_image
    
    # Model
    model = smp.Unet(encoder_name='efficientnet-b0', encoder_weights='imagenet', in_channels=3, classes=1).to(device)
    # criterion = torch.nn.BCEWithLogitsLoss()
    criterion = smp.losses.DiceLoss(smp.losses.BINARY_MODE, from_logits=True)
    optimizer = torch.optim.Adam(model.parameters(), lr=cfg.lr, weight_decay=1e-6)
    
    if cfg.train:
        # Dataset and DataLoader
        train_dataset = BeachDataset(image_subdir, mask_subdir, list_image_train, thresh_distance=cfg.mask_thresh_distance)
        valid_dataset = BeachDataset(image_subdir, mask_subdir, list_image_valid, thresh_distance=cfg.mask_thresh_distance)
        train_dataloader = DataLoader(train_dataset, batch_size=cfg.batch_size, shuffle=False, num_workers=cfg.num_workers)
        valid_dataloader = DataLoader(valid_dataset, batch_size=cfg.batch_size, shuffle=False, num_workers=cfg.num_workers)
        
        log.info("Number of samples ...")
        log.info(f"\tTrain >> {len(train_dataset)}")
        log.info(f"\tValid >> {len(valid_dataset)}")
        best_loss = float('inf')
        train_metrics, test_metrics = defaultdict(list), defaultdict(list)
        t1 = time.time()
        for epoch in range(cfg.max_epochs):
            train_cm, test_cm = [], []
            train_loss, test_loss = 0., 0.
            fids, outputs = [], []
            
            # Train
            model.train()
            # for (fid, image, mask) in tqdm(train_dataloader, desc='Train batch'):
            for (fid, image, mask) in train_dataloader:
                image, mask = image.to(device), mask.to(device).float()
                optimizer.zero_grad()
                output = model(image).squeeze(1)
                loss = criterion(output, mask)
                pred_mask = output.sigmoid()
                pred_mask = (pred_mask > 0.5).float()
                loss.backward()
                optimizer.step()
                train_loss += loss.item()*image.size(0)
                train_cm.append(smp.metrics.get_stats(pred_mask.long(), output.long(), mode='binary'))
            
            # Validation
            model.eval()
            with torch.inference_mode():
                # for (fid, image, mask) in tqdm(valid_dataloader, desc='Valid batch'):
                for (fid, image, mask) in valid_dataloader:
                    image, mask = image.to(device), mask.to(device).float()
                    output = model(image).squeeze(1)
                    loss = criterion(output, mask)
                    pred_mask = output.sigmoid()
                    pred_mask = (pred_mask > 0.5).float()
                    test_loss += loss.item()*image.size(0)
                    fids.extend(fid)
                    outputs.extend(pred_mask.detach().cpu().numpy())
                    test_cm.append(smp.metrics.get_stats(pred_mask.long(), output.long(), mode='binary'))
            
            # Calculate average losses and metrics
            train_loss /= len(train_dataloader.sampler)
            train_metrics['loss'].append(train_loss)
            train_cms = torch.cat([torch.stack(tcm).detach().cpu() for tcm in train_cm], axis=1)
            train_metrics['iou_perimage'] = smp.metrics.iou_score(*train_cms, reduction='micro-imagewise')
            train_metrics['iou_dataset'] = smp.metrics.iou_score(*train_cms, reduction='micro')
            test_loss /= len(valid_dataloader.sampler)
            test_metrics['loss'].append(test_loss)
            test_cms = torch.cat([torch.stack(tcm).detach().cpu() for tcm in test_cm], axis=1)
            test_metrics['iou_perimage'] = smp.metrics.iou_score(*test_cms, reduction='micro-imagewise')
            test_metrics['iou_dataset'] = smp.metrics.iou_score(*test_cms, reduction='micro')
            log.info(f"epoch: [{epoch}/{cfg.max_epochs-1}] | train loss: {train_loss:.5g} | test loss: {test_loss:.5g}")
            # Track and save best model
            if test_loss < best_loss:
                log.info(f"\tSaved model >> {Path(cfg.model_path)}")
                torch.save(model.state_dict(), Path(cfg.model_path))
                best_loss = test_loss
        pd.DataFrame({'train': train_metrics, 'test': test_metrics}).to_pickle(Path(Path(cfg.model_path).parent, 'loss_metric.pkl'))
        log.info(f"Time train >> {str(timedelta(seconds=time.time()-t1))}")
    
    # Test
    t2 = time.time()
    # Dataset and DataLoader
    test_dataset = BeachDataset(image_subdir, mask_subdir, list_image_test, thresh_distance=cfg.mask_thresh_distance)
    test_dataloader = DataLoader(test_dataset, batch_size=cfg.batch_size, shuffle=False, num_workers=cfg.num_workers)
    log.info("Number of samples ...")
    log.info(f"\tTest >> {len(test_dataset)}")
    
    fids, outputs = [], []
    model.load_state_dict(torch.load(Path(cfg.model_path), map_location=device))
    model.eval()
    with torch.inference_mode():
        # for (fid, image, _) in tqdm(test_dataloader, desc='Eval test'):
        for (fid, image, _) in test_dataloader:
            image = image.to(device)
            output = model(image).squeeze(1)
            pred_mask = output.sigmoid()
            pred_mask = (pred_mask > 0.5).float()
            fids.extend(fid)
            outputs.extend(pred_mask.detach().cpu().numpy())
    
    # Save outputs
    log.info("\nSAVING GEOTIFF ...")
    # Get metadata from one of mask files, but include coord info from image file
    with rasterio.open(Path(cfg.profmask_path)) as dstm:
        profile = dstm.profile
    profile.pop('crs', None); profile.pop('transform', None)
    for fid, output in zip(fids, outputs):
        file_utils.write_geotiff(output, Path(maskpred_subdir, f"{image_prefix.replace('image', 'maskpred')}_{fid}.tif"),
                                 profile_tif_filepath=Path(image_subdir, f"{image_prefix}_{fid}.tif"),
                                 profile_params=profile)
    log.info(f"\tSaved GeoTiff >> {maskpred_subdir}")
    # Save to shapefile
    list_maskpred = glob.glob(str(Path(maskpred_subdir, '*.tif')))
    file_utils.write_shapefile(list_maskpred, save_filepath=str(maskpred_subdir)+'_polygons.shp.zip')
    
    log.info(f"Time test >> {str(timedelta(seconds=time.time()-t2))}")
    log.info(f"Time >> {str(timedelta(seconds=time.time()-t0))}")


if __name__ == '__main__':
    main()
