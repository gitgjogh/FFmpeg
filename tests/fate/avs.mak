# AVS (Audio Video Coding Standard) video decoder tests.
#
# The samples below are cut from the public AVS conformance dataset
# (AVS1-P16 Guangdian and Jizhun suites); each was verified to decode
# bit-exactly to the prefix of the reference decoder (GDM4.2 / RM52K)
# output of the corresponding full conformance stream.

# AVS1-P16 Guangdian profile, arithmetic entropy coding (AEC),
# interlaced sequence (from STEP1/35_Tsinghua_HS_0_0_0x48)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-guangdian-aec
fate-cavs-guangdian-aec: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/guangdian-aec-cif.avs -an

# AVS1-P16 Guangdian profile, AEC + weighting quant + field-coded
# pictures with enhanced field-P/B modes (from STEP1/83_PKU_0_0_6.0)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-guangdian-aec-field
fate-cavs-guangdian-aec-field: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/guangdian-aec-field.avs -an

# AVS1-P2 Jizhun profile, 4:2:2 chroma format (from
# AVS1-P2_JZP09/FINAL/30_Hisilicon_0_0_0x42)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-jizhun-422
fate-cavs-jizhun-422: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/jizhun-422-hisilicon.avs -an

# AVS1-P2 Jizhun profile, slice-level weighted prediction
# (from 21_cesi_6.0_frame of the 2009 standard conformance set)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-jizhun-wp
fate-cavs-jizhun-wp: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/jizhun-wp-cesi.avs -an

# AVS1-P2 Jizhun profile, field-coded pictures
# (from 01_cesi_step5_4.0_field of the 2009 standard conformance set)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-jizhun-field
fate-cavs-jizhun-field: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/jizhun-field-cesi.avs -an

# AVS1-P2 Jizhun profile, low_delay stream: bbv_check_times in the
# picture header, mid-byte header end with MPEG-style stuffing bytes
# and extension/user data blocks (from 19_broadcom_0_0_4.0 of the 2009
# standard conformance set)
FATE_AVS-$(call FRAMECRC, CAVSVIDEO, CAVS, CAVSVIDEO_PARSER) += fate-cavs-jizhun-lowdelay
fate-cavs-jizhun-lowdelay: CMD = framecrc -i $(TARGET_SAMPLES)/cavs/jizhun-lowdelay-broadcom.avs -an

FATE_SAMPLES_FFMPEG += $(FATE_AVS-yes)
fate-avs: $(FATE_AVS-yes)
