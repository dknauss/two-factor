<?php
/**
 * Bootstrap the PHPUnit tests.
 *
 * @package Two_Factor_Enrollment
 */

require_once dirname( __DIR__ ) . '/vendor/autoload.php';

$two_factor_enrollment_tests_dir = getenv( 'WP_TESTS_DIR' );

if ( ! $two_factor_enrollment_tests_dir ) {
	$two_factor_enrollment_tests_dir = '/tmp/wordpress-tests-lib';
}

require_once $two_factor_enrollment_tests_dir . '/includes/functions.php';

tests_add_filter(
	'muplugins_loaded',
	function () {
		// Two Factor is expected alongside this plugin: wp-content/plugins/two-factor in wp-env.
		$two_factor = dirname( dirname( __DIR__ ) ) . '/two-factor/two-factor.php';

		if ( ! file_exists( $two_factor ) ) {
			echo "Two Factor plugin not found at {$two_factor}\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			exit( 1 );
		}

		require_once $two_factor;
		require_once dirname( __DIR__ ) . '/two-factor-enrollment.php';

		two_factor_enrollment_bootstrap();
	}
);

require_once $two_factor_enrollment_tests_dir . '/includes/bootstrap.php';
