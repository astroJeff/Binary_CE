! ***********************************************************************
!
!   Copyright (C) 2010  Bill Paxton
!
!   MESA is free software; you can use it and/or modify
!   it under the combined terms and restrictions of the MESA MANIFESTO
!   and the GNU General Library Public License as published
!   by the Free Software Foundation; either version 2 of the License,
!   or (at your option) any later version.
!
!   You should have received a copy of the MESA MANIFESTO along with
!   this software; if not, it is available at the mesa website:
!   http://mesa.sourceforge.net/
!
!   MESA is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
!   See the GNU Library General Public License for more details.
!
!   You should have received a copy of the GNU Library General Public License
!   along with this software; if not, write to the Free Software
!   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
!
! ***********************************************************************

      module CE_torque




      ! NOTE: if you'd like to have some inlist controls for your routine,
      ! you can use the x_ctrl array of real(dp) variables that is in &controls
      ! e.g., in the &controls inlist, you can set
      !     x_ctrl(1) = <my_special_param>
      ! where <my_special_param> is a real value such as 0d0 or 3.59d0
      ! Then in your routine, you can access that by
      !     s% x_ctrl(1)
      ! of course before you can use s, you need to get it using the id argument.
      ! here's an example of how to do that -- add these lines at the start of your routine:
      !         use star_lib, only: star_ptr
      !         type (star_info), pointer :: s
      !         call star_ptr(id, s, ierr)
      !         if (ierr /= 0) then ! OOPS
      !            return
      !         end if
      !
      ! for integer control values, you can use x_integer_ctrl
      ! for logical control values, you can use x_logical_ctrl

      use star_def
      use const_def
      use CE_orbit, only: AtoP, TukeyWindow, calc_quantities_at_comp_position
      implicit none




      contains


      ! Angular momentum prescription from CE
      ! Based off example from mesa/star/other/other_torque.f

      subroutine CE_inject_am(id, ierr)

         use const_def, only: Rsun
         integer, intent(in) :: id
         integer, intent(out) :: ierr
         type (star_info), pointer :: s
         integer :: k
         real(dp) :: a_tukey, mass_to_be_spun, ff
         real(dp) :: CE_companion_position, CE_companion_mass, CE_n_acc_radii, CE_torque
         real(dp) :: R_acc, R_acc_low, R_acc_high
         real(dp) :: v_rel, v_rel_div_csound, M_encl, rho_at_companion, scale_height_at_companion

         ierr = 0
         call star_ptr(id, s, ierr)
         if (ierr /= 0) return


         CE_companion_position = s% xtra2
         CE_companion_mass = s% xtra4


         ! If the star is in the initial relaxation phase, skip torque calculations
         if (s% doing_relax) return
         ! If companion is outside star, skip torque calculations
         if (CE_companion_position*Rsun > s% r(1)) return



         ! Load angular momentum dissipated in the envelope from the orbit decrease
         CE_n_acc_radii = s% xtra5
         CE_torque = s% xtra6

         call calc_quantities_at_comp_position(id, ierr)

         R_acc_low = s% xtra12
         R_acc_high = s% xtra13
         M_encl = s% xtra14
         v_rel = s% xtra15
         v_rel_div_csound = s% xtra16
         rho_at_companion = s% xtra17
         scale_height_at_companion = s% xtra18

         ! Tukey window scale
         a_tukey = 0.5

         ! First calculate the mass in which the angular momentum will be deposited
         mass_to_be_spun = 0.0
         do k = 1, s% nz
            if (s% r(k) < CE_companion_position*Rsun) then
               R_acc = R_acc_low
            else
               R_acc = R_acc_high
            end if
            ff = TukeyWindow((s% r(k) - CE_companion_position*Rsun)/(CE_n_acc_radii * R_acc), a_tukey)
            mass_to_be_spun = mass_to_be_spun + s% dm(k) * ff
         end do

         ! Now redo the loop and add the extra torque
         do k = 1, s% nz
            if (s% r(k) < CE_companion_position*Rsun) then
               R_acc = R_acc_low
            else
               R_acc = R_acc_high
            end if
            ff = TukeyWindow((s% r(k) - CE_companion_position*Rsun)/(CE_n_acc_radii * R_acc), a_tukey)
            s% extra_jdot(k) = CE_torque / mass_to_be_spun * ff
         end do



      end subroutine CE_inject_am


      end module CE_torque
