run_logged $OMARCHY_INSTALL/login/plymouth.sh

# Configure autologin after plymouth creates the service
run_logged $OMARCHY_INSTALL/config/autologin.sh

run_logged $OMARCHY_INSTALL/login/limine-snapper.sh
run_logged $OMARCHY_INSTALL/login/enable-mkinitcpio.sh
run_logged $OMARCHY_INSTALL/login/alt-bootloaders.sh
