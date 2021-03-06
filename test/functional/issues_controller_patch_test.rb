# -*- encoding : utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

# Reuse the default test
require File.expand_path('test/functional/issues_controller_test', RAILS_ROOT)

class IssuesControllerTest < ActionController::TestCase

  fixtures :all

  context "PrivateIssuesPlugin" do
    setup do
      @project = Project.find(1)
      @request.session[:user_id] = 2
      @issue = Issue.find(1)

      @issue.update_attributes!({:private => true, :author_id => 1})
    end

    context "view hook" do
      context "with manage permission" do
        setup do
          Role.find(1).add_permission! :manage_private_issues
          get :new, :project_id => @project, :tracker_id => 1
        end
        should_respond_with :success
        should_render_template :new
        should "render private checkbox" do
          assert_tag :tag => 'input', :attributes => {:name => 'issue[private]',
                                                      :type => 'checkbox',
                                                      :checked => nil}
        end
      end

      context "without manage permission" do
        setup do
          get :new, :project_id => @project, :tracker_id => 1
        end

        should_respond_with :success
        should_render_template :new
        should "render private checkbox" do
          assert_no_tag :tag => 'input', :attributes => {:name => 'issue[private]',
                                                         :type => 'checkbox',
                                                         :checked => nil}
        end
      end
    end

    # This is more related to IssuePatch where the safe attribute is declared
    # Testing in controller ensures that :if lambda will actually work and User.current is considered
    context "POST create" do
      context "without permission" do

        setup do
          post :create, :project_id => @project.id,
               :issue => {:tracker_id => 3,
                          :status_id => 2,
                          :subject => 'This is the test_new issue',
                          :description => 'This is the description',
                          :priority_id => 5,
                          :start_date => '2010-11-07',
                          :estimated_hours => '',
                          :custom_field_values => {'2' => 'Value for field 2'},
                          :private => '1'}
        end

        should "not create private issue" do
          assert !Issue.last.private
        end

      end

      context "with permission" do
        setup do
          Role.find(1).add_permission! :manage_private_issues
          post :create, :project_id => @project.id,
               :issue => {:tracker_id => 3,
                          :status_id => 2,
                          :subject => 'This is the test_new issue',
                          :description => 'This is the description',
                          :priority_id => 5,
                          :start_date => '2010-11-07',
                          :estimated_hours => '',
                          :custom_field_values => {'2' => 'Value for field 2'},
                          :private => '1'}
        end

        should "redirect to issue" do
          assert_redirected_to :controller => 'issues', :action => 'show', :id => Issue.last.id
        end

        should "mark issue as private" do
          assert Issue.last.private
        end
      end
    end

    # Based on Redmine rev 5466
    # http://www.redmine.org/projects/redmine/repository/revisions/5466/diff/trunk/test/functional/issues_controller_test.rb
    context "GET index" do
      context "without permission" do
        setup do
          get :index, :per_page => 100
        end
        should_respond_with :success
        should_assign_to :issues
        should "not assign private issues" do
          assert_nil assigns(:issues).detect { |issue| issue.private? }
        end
      end

      context "for assignee" do
        setup do
          @issue.reload.update_attribute(:assigned_to_id, 2)
          get :index, :per_page => 100
        end

        should_respond_with :success
        should_assign_to :issues

        should "assign his issue" do
          assert_include assigns(:issues), @issue
        end
      end


    end

    context "#find_issue" do
      setup do
        @issue.reload
      end

      context "user is an author" do
        setup do
          @issue.update_attribute(:author, User.find(2))
          get :show, :id => @issue
        end

        should_respond_with :success
      end

      context "user is an assignee" do
        setup do
          @issue.update_attribute(:assigned_to, User.find(2))
          get :show, :id => @issue
        end

        should_respond_with :success
      end

      context "without permission" do
        setup do
          get :show, :id => @issue
        end

        should_respond_with 403
      end

      context "with permission" do
        setup do
          Role.find(1).add_permission! :view_private_issues
          get :show, :id => @issue
        end

        should_respond_with :success
      end

      context "child issue (deprecated)" do
        setup do
          @child = Issue.generate_for_project!(@project) do |issue|
            issue.parent_issue_id = @issue.id
          end
        end

        context "without permission" do
          setup do
            get :show, :id => @child
          end

          #should_respond_with 403
          should_respond_with :success
        end

        context "with permission" do
          setup do
            Role.find(1).add_permission! :view_private_issues
            get :show, :id => @child
          end

          should_respond_with :success
        end
      end

    end

  end
end