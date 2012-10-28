# encoding: utf-8
require 'spec_helper'

describe "Omniauths" do
  context 'OpenId' do
    context 'known user' do
      before do
        @admin = FactoryGirl.create(:admin_user)
        login @admin
        visit identities_path
        click_on 'MyOpenID'
      end

      it 'Adds/Removes a MyOpenID identity' do
        current_path.should eq(identities_path)
        page.should have_content('موفقیت')
        page.should have_content('حذف این حساب')
        click_link 'حذف'
        page.should have_content('موفقیت')
      end

      it 'raises error if account already exist' do
        click_on 'MyOpenID'
        page.should have_content('قبلا در سایت ثبت شده است')
      end
    end

    context 'Unknown user' do
      before do
        OmniAuth.config.add_mock :myopenid, uid: "12345", info: { name: "Arash Joon", email: 'ArashJJ@jmail.com' }
        visit new_session_path
        click_link 'MyOpenID'
      end

      it 'creates account with openid' do
        click_button 'تایید'
        current_path.should eq(root_path)
        page.should have_content('موفقیت')
      end

      it 'signes in user if identity exist' do
        click_button 'تایید'
        click_link 'خروج' # signe out before testing again
        visit new_session_path
        click_link 'MyOpenID'
        page.should have_content('با موفقیت وارد شدید')
      end

      it 'cancels creating new account' do
        click_button 'لغو'
        page.should have_content('ایجاد حساب لغو شد')
      end

      it 'doesnt let visit identities page' do
        visit identities_path
        page.should have_content('not authorized')
      end
    end

    context 'Error' do
      before do
        OmniAuth.config.mock_auth[:myopenid] = :invalid_credentials
      end

      it 'raises error if there is an error with provider' do
        visit new_session_path
        click_link 'MyOpenID'
        page.should have_content('خطایی در سرویس‌دهنده رخ داد')
      end
    end
  end
end