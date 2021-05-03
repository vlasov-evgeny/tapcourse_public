class UserCoursePackageOrdersController < ApplicationController
  before_action :set_user_course_package_order, only: [:show, :destroy, :edit, :update, :join_user]

  # TODO: Добавить права для всех методов!!! + VIEW + ROUTE + Связующая таблица пакет - юнит
  def index
    authorize UserCoursePackageOrder
    all_orders = policy_scope(UserCoursePackageOrder)
    @user_course_package_orders = if !params[:creator_id].nil? && !params[:user_id].nil?
                                    all_orders.where(creator_id: params[:creator_id],
                                                                 user_id: params[:user_id])
                                  elsif !params[:creator_id].nil?
                                    all_orders.by_creator(params[:creator_id])
                                  elsif !params[:user_id].nil?
                                    all_orders.by_user(params[:user_id])
                                  else
                                    all_orders.order(created_at: :desc)
                                  end
    set_pagination_meta(total: @user_course_package_orders.count)
    @user_course_package_orders = @user_course_package_orders.paginate(page: page, per_page: per_page)
  end

  def show
    authorize @user_course_package_order
  end

  def update
    authorize @user_course_package_order
    @course.update(user_course_package_order_params)
    render :edit
  end

  def edit
    authorize @user_course_package_order
  end

  def create
    authorize UserCoursePackageOrder
    user_coupon = Coupon.find_by(code: params[:order][:coupon_code])
    @user_course_package_order = UserCoursePackageOrder.create!(user_course_package_order_params
                                                                    .merge(coupon: user_coupon,
                                                                           creator: current_user))
    render :edit
  end

  def buy
    user_coupon = Coupon.find_by(code: params[:coupon_code])
    @user_course_package_order = UserCoursePackageOrder.create!(
        course_package_ids: params[:course_package_ids],
        user_id: current_user.id,
        coupon: user_coupon
    )
    render :show
  end

  def destroy
    authorize @user_course_package_order
    @user_course_package_order.reject!
  end

  def join_user
    authorize @user_course_package_order
    @user_course_package_order.join_user(current_user)
    render :show
  end

  private

  def user_course_package_order_params
    params.require(:order).permit(:email, :phone_number, :price, :user_id,
                                  :creator_id, :external_payment, :description, course_package_ids: [])
  end

  def set_user_course_package_order
    @user_course_package_order = UserCoursePackageOrder.find(params[:id])
  end
end
