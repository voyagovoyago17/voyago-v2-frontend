import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_notification.dart';
import 'community/comments_sheet.dart';
import 'place_review_sheet.dart';
import 'packing/packing_sheet.dart';

/// La notification mène-t-elle quelque part (écran, fiche) ?
bool canOpenNotification(AppNotification n) {
  switch (n.type) {
    case 'arrival':
      return n.lat != null && n.lng != null && !n.isReviewed;
    case 'trip_ready':
    case 'trip_remixed':
      return n.tripId?.isNotEmpty ?? false;
    case 'tribe_trip':
      return n.data['circle_id'] != null && n.data['plan_id'] != null;
    case 'comment':
      return n.data['target_type'] != null && n.data['target_id'] != null;
    case 'circle_request':
      // Un cercle privé refusé ne s'ouvre pas
      return n.data['circle_id'] != null && n.data['kind'] != 'rejected';
    case 'system':
      // Journal prêt, rappel de départ (valise) ou récap du soir
      return (n.data['journal'] == true || n.data['packing'] == true || n.data['recap'] == true) &&
          (n.tripId?.isNotEmpty ?? false);
    default:
      return false;
  }
}

/// Ouvre l'écran d'une notification : depuis la cloche comme depuis un push touché.
void openNotificationTarget(BuildContext context, AppNotification n) {
  if (!canOpenNotification(n)) return;
  switch (n.type) {
    case 'arrival':
      showPlaceReviewSheet(
        context,
        ReviewTarget(
          name: n.placeName ?? n.title,
          lat: n.lat!,
          lng: n.lng!,
          imageUrl: n.data['image_url']?.toString(),
          destination: n.data['destination']?.toString(),
          tripId: n.tripId,
        ),
        fromArrival: true,
      );
    case 'trip_ready':
    case 'trip_remixed':
      context.go('/itinerary/${n.tripId}');
    case 'tribe_trip':
      context.push('/circle/${n.data['circle_id']}/plan/${n.data['plan_id']}');
    case 'comment':
      showCommentsSheet(
        context,
        targetType: n.data['target_type'].toString(),
        targetId: n.data['target_id'].toString(),
      );
    case 'system':
      if (n.data['packing'] == true) {
        showPackingSheet(context, tripId: n.tripId!, destination: n.data['destination']?.toString() ?? 'ton voyage');
      } else if (n.data['recap'] == true) {
        context.go('/itinerary/${n.tripId}');
      } else {
        context.push('/journal/${n.tripId}');
      }
    case 'circle_request':
      context.push('/circle/${n.data['circle_id']}');
  }
}
