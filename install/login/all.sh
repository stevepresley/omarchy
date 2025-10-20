run_logged $OMARCHY_INSTALL/login/plymouth.sh

# Configure greetd display manager (replaces autologin)
run_logged $OMARCHY_INSTALL/login/greetd.sh

run_logged $OMARCHY_INSTALL/login/limine-snapper.sh
run_logged $OMARCHY_INSTALL/login/enable-mkinitcpio.sh
run_logged $OMARCHY_INSTALL/login/alt-bootloaders.sh
