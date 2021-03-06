#--
# Copyright (c) 2009-2010 Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#++

require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require File.join(RailsParent.parent, "test","devise_helper")
#require 'test/unit'


class MailsettingControllerTest < ActionController::TestCase

  def setup
    devise_sign_in
    Mailsetting.stubs(:find).returns Mailsetting.new({:smtp_server => "oldserver", :user => "foo", :password => "bar", :password_confirmation => "bar", :transport_layer_security => "no"})
  end

  test "check 'show' result" do
    ret = get :show, :format => "xml"
    # success (200 OK)
    assert_response :success

    # is returned a valid XML?
    ret_hash = Hash.from_xml(ret.body)
    assert ret_hash
    assert ret_hash.has_key?("mail")
    assert ret_hash["mail"].has_key?("smtp_server")
  end

  test "xml put success" do
    Mailsetting.any_instance.stubs(:update).returns(true)
    request.env['HTTP_REFERER'] = 'mailsetting'
    ret = post :update, :mailsetting => {
      :smtp_server => "newserver",
      :user=>"User",
      :password => 'password',
      :password_confirmation => 'password'
    }, :format => "xml"

    assert_response :success
  end

# shame, YaPI currently always succeedes
#  test "put failure" do
#  end


end
