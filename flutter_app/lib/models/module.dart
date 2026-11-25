part of '../main.dart';

class Module {
  final String title,path; final IconData icon; final bool adminOnly;
  const Module(this.title,this.path,this.icon,{this.adminOnly=false});
}
const residentModules = [
  Module('Facilities','/facilities',Icons.meeting_room_outlined),Module('My Bookings','/bookings/my',Icons.event_available_outlined),
  Module('Repairs','/repairs/my',Icons.build_outlined),Module('Vehicles','/vehicles/my',Icons.directions_car_outlined),
  Module('Parcels','/parcels/my',Icons.inventory_2_outlined),Module('Bills','/bills/my',Icons.receipt_long_outlined),
  Module('Suggestions','/suggestions/my',Icons.feedback_outlined),Module('Community Rules','/rules',Icons.menu_book_outlined),
  Module('Messages','/messages/my',Icons.chat_bubble_outline),Module('Home Services','/services',Icons.cleaning_services_outlined),
  Module('Service Requests','/service-requests/my',Icons.handyman_outlined),
  Module('Announcements','/announcements',Icons.campaign_outlined),
];
const adminModules = [
  Module('Residents','/admin/residents',Icons.people_alt_outlined),Module('Facility Bookings','/admin/bookings',Icons.event_note_outlined),
  Module('Repairs','/admin/repairs',Icons.build_outlined),Module('Vehicles','/admin/vehicles',Icons.directions_car_outlined),
  Module('Parcels','/admin/parcels',Icons.inventory_2_outlined),Module('Bills','/admin/bills',Icons.receipt_long_outlined),
  Module('Suggestions','/admin/suggestions',Icons.feedback_outlined),Module('Community Rules','/rules',Icons.menu_book_outlined),
  Module('Messages','/admin/messages',Icons.chat_bubble_outline),Module('Service Requests','/admin/service-requests',Icons.handyman_outlined),
  Module(
  'Announcements',
  '/admin/announcements',
  Icons.campaign_outlined,
  adminOnly: true,
),
];

