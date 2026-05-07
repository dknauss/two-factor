<?php
/**
 * Two Factor Compat Class Tests.
 *
 * @package Two_Factor
 */

/**
 * Class Test_ClassTwoFactorCompat
 *
 * @package Two_Factor
 * @group core
 */
class Test_ClassTwoFactorCompat extends WP_UnitTestCase {

	/**
	 * Test init() registers the Jetpack remember-me compatibility filter.
	 *
	 * @covers Two_Factor_Compat::init
	 */
	public function test_init_registers_jetpack_rememberme_filter() {
		$compat = new Two_Factor_Compat();

		$this->assertFalse( has_filter( 'two_factor_rememberme', array( $compat, 'jetpack_rememberme' ) ) );

		$compat->init();

		$this->assertSame( 10, has_filter( 'two_factor_rememberme', array( $compat, 'jetpack_rememberme' ) ) );

		remove_filter( 'two_factor_rememberme', array( $compat, 'jetpack_rememberme' ), 10 );
	}

	/**
	 * Test jetpack_rememberme() returns the incoming remember-me state when the
	 * request is not a Jetpack SSO login.
	 *
	 * @covers Two_Factor_Compat::jetpack_rememberme
	 */
	public function test_jetpack_rememberme_returns_incoming_value_without_sso_request() {
		$compat = new Two_Factor_Compat();

		$this->assertFalse( $compat->jetpack_rememberme( false ) );
		$this->assertTrue( $compat->jetpack_rememberme( true ) );
	}

	/**
	 * Test jetpack_is_sso_active() returns false when Jetpack is unavailable.
	 *
	 * @covers Two_Factor_Compat::jetpack_is_sso_active
	 */
	public function test_jetpack_is_sso_active_returns_false_without_jetpack() {
		$compat = new Two_Factor_Compat();

		$this->assertFalse( $compat->jetpack_is_sso_active() );
	}

	/**
	 * Test jetpack_is_sso_active() returns true when Jetpack reports the SSO
	 * module as active.
	 *
	 * @covers Two_Factor_Compat::jetpack_is_sso_active
	 */
	public function test_z_jetpack_is_sso_active_returns_true_when_jetpack_sso_is_active() {
		$class_name = get_class(
			new class() {
				/**
				 * Simulate Jetpack SSO module activity.
				 *
				 * @param string $module Module slug.
				 * @return bool
				 */
				public static function is_module_active( $module ) {
					return 'sso' === $module;
				}
			}
		);

		class_alias( $class_name, 'Jetpack' );

		$compat = new Two_Factor_Compat();

		$this->assertTrue( $compat->jetpack_is_sso_active() );
	}
}
