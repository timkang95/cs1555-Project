create or replace view completeTickets
as select b.departure_city, b.arrival_city, b.departure_time, b.arrival_time, c.reservation_number, c.leg, d.cost, d.ticketed
from Flight b, Reservation_detail c, Reservation d
where (b.flight_number = c.flight_number)
	AND (c.reservation_number = d.reservation_number);


-- price -> flight (arrival and departure) -> reversation detail -> reservation
create or replace trigger adjustTicket
after update
on Price
for each row
begin
	update Reservation set Cost = case
		when reservation_number = (select reservation_number
																  from completeTickets
																	where :new.departure_city = departure_city
																		AND :new.arrival_city = arrival_city
																		AND ticketed = 'N'
																		AND cast(departure_time as int) < cast(arrival_time as int))
		then :new.high_price
	 	when reservation_number = (select reservation_number
 																  from completeTickets
 																	where :new.departure_city = departure_city
																		AND :new.arrival_city = arrival_city
																		AND ticketed = 'N'
																		AND cast(departure_time as int) > cast(arrival_time as int))
		then :new.low_price
		end
	where reservation_number = (select reservation_number
																from completeTickets
																where :new.departure_city = departure_city
																	AND :new.arrival_city = arrival_city
																	AND ticketed = 'N');
end;
/

create or replace view seatingCheck
as select a.reservation_number, a.flight_number, b.airline_id, b.plane_type, c.plane_capacity
from Reservation_detail a, Flight b, Plane c
where (a.flight_number = b.flight_number) 
	AND (b.plane_type = c.plane_type);

--reservation_detail -> flight_number -> plane 
create or replace trigger planeUpgrade
before insert
on Reservation
for each row
begin 
	update Flight set plane_type = select plane_type
									from plane
									where (select plane_capacity
											from seatingCheck
											where :new.reservation_number = reservation_number)
										<  plane_capacity
										AND ROWNUM=1
									order by plane_capacity desc)
		where (select plane_capacity
			  from seatingCheck
			  where :new.reservation_number = reservation_number)
				AND (select plane_capacity
						from seatingCheck
						where :new.reservation_number = reservation_number)
					= (select count(reservation_number)
						from seatingCheck
						where :new.reservation_number = reservation_number);
end;
/
